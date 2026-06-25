# ServiceManager.ps1 - Service management module

$script:ServiceJobs = @{}

# ===== Docker Desktop 辅助函数 =====

function Start-DockerDesktop {
    <#
    .SYNOPSIS
        尝试启动 Docker Desktop（若未运行）
    #>
    $dockerCheck = & docker info 2>&1
    if ("$dockerCheck" -match '(?i)(Server Version|Containers:)') {
        return $true
    }

    $knownPaths = @(
        "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
        "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
        "${env:ProgramFiles(x86)}\Docker\Docker\Docker Desktop.exe",
        "$env:LOCALAPPDATA\Docker\Docker Desktop.exe",
        "$env:ProgramW6432\Docker\Docker\Docker Desktop.exe"
    )

    $dockerExe = $null
    foreach ($p in $knownPaths) {
        if (Test-Path $p) { $dockerExe = $p; break }
    }

    # 如果没找到已知路径，尝试从快捷方式查找
    if (-not $dockerExe) {
        $startMenu = [Environment]::GetFolderPath('CommonStartMenu')
        $shortcut = Get-ChildItem -Path "$startMenu\*" -Recurse -Include "Docker Desktop.lnk" -ErrorAction SilentlyContinue |
                    Select-Object -First 1
        if ($shortcut) { $dockerExe = $shortcut.FullName }
    }

    # 最后的办法: 尝试 which docker 路径推断
    if (-not $dockerExe -and (Get-Command docker -ErrorAction SilentlyContinue)) {
        $dockerCmd = (Get-Command docker).Source
        $dockerExe = Join-Path (Split-Path $dockerCmd -Parent) "Docker Desktop.exe"
        if (-not (Test-Path $dockerExe)) { $dockerExe = $null }
    }

    if (-not $dockerExe) { return $false }

    Write-LauncherLog -Message "Starting Docker Desktop from: $dockerExe" -Level "INFO"
    try {
        $proc = Start-Process -FilePath $dockerExe -WindowStyle Hidden -PassThru
        # 不等进程退出（Docker Desktop 会保持运行）
        return $true
    } catch {
        Write-LauncherLog -Message "Failed to start Docker Desktop: $_" -Level "WARN"
        return $false
    }
}

function Wait-ForDockerDaemon {
    <#
    .SYNOPSIS
        等待 Docker 守护进程可用，最多等 timeoutSeconds 秒
    #>
    param([int]$TimeoutSeconds = 60)

    $startTime = Get-Date
    while ((Get-Date) -lt $startTime.AddSeconds($TimeoutSeconds)) {
        $dockerCheck = & docker info 2>&1
        if ("$dockerCheck" -match '(?i)(Server Version|Containers:)') {
            return $true
        }
        Start-Sleep -Seconds 2
    }
    return $false
}

# ===== 兼容性端口检查（不依赖 "LISTENING" 英文关键词） =====

function Test-PortListening {
    param([int]$Port)
    # netstat -an 用数字格式，不依赖语言
    $lines = netstat -an 2>&1 | Select-String ":$Port\s" | Select-String "LISTEN|听|ESCUCH|ECOUTE|LAUSCHE"
    return [bool]$lines
}

# ===== 原有函数 =====

function Wait-ForPort {
    param([int]$Port, [int]$TimeoutSeconds = 60)
    $startTime = Get-Date
    while ((Get-Date) -lt $startTime.AddSeconds($TimeoutSeconds)) {
        $check = Check-Port -Port $Port
        if ($check.InUse) { return $true }
        Start-Sleep -Milliseconds 1000
    }
    return $false
}

function Start-RedisService {
    param([scriptblock]$LogCallback)
    if (-not $LogCallback) { $LogCallback = { param($m) } }
    $result = @{ Success = $false; Message = "" }

    # 1. 先检查端口是否已被占用
    $portCheck = Check-Port -Port 6379
    if ($portCheck.InUse) {
        $result.Success = $true
        $result.Message = "Redis already running (port 6379)"
        & $LogCallback "Redis already running (port 6379)"
        return $result
    }

    # 2. 检查 docker 命令是否存在
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        $result.Message = "Docker command not found. Please install Docker Desktop first."
        & $LogCallback "Docker command not found. Please install Docker Desktop first."
        return $result
    }

    # 3. 检查 Docker 是否在运行，不在则尝试启动
    $dockerCheck = & docker info 2>&1
    $dockerOk = "$dockerCheck" -match '(?i)(Server Version|Containers:)'

    if (-not $dockerOk) {
        & $LogCallback "Docker Desktop not running, attempting to start..."
        $started = Start-DockerDesktop
        if ($started) {
            & $LogCallback "Docker Desktop launch initiated, waiting for daemon..."
            $waited = Wait-ForDockerDaemon -TimeoutSeconds 60
            if (-not $waited) {
                $result.Message = "Docker Desktop did not become ready within 60s"
                & $LogCallback "Docker Desktop did not become ready within 60s"
                return $result
            }
            & $LogCallback "Docker Desktop is now ready"
        } else {
            & $LogCallback "Could not find Docker Desktop executable."
            $result.Message = "Docker Desktop not found. Please start it manually."
            return $result
        }
    }

    # 4. 尝试启动 Redis（含重试）
    & $LogCallback "Starting Redis (Docker)..."

    $maxRetries = 3
    $attempt = 0
    while ($attempt -lt $maxRetries) {
        $attempt++
        & $LogCallback "  Attempt $attempt/$maxRetries..."

        # 清理旧容器
        & docker rm -f yami-redis 2>&1 | Out-Null

        # 拉取镜像（后台静默拉取，更快）
        & docker pull redis:5.0.4 2>&1 | Out-Null

        # 启动容器
        & docker run -d --name yami-redis -p 6379:6379 redis:5.0.4 2>&1 | Out-Null

        # 轮询等待端口就绪（最多 20 秒）
        $waitStart = Get-Date
        $portReady = $false
        while ((Get-Date) -lt $waitStart.AddSeconds(20)) {
            $check = Test-PortListening -Port 6379
            if ($check) {
                $portReady = $true
                break
            }
            Start-Sleep -Milliseconds 1000
        }

        if ($portReady) {
            $result.Success = $true
            $result.Message = "Redis started"
            & $LogCallback "Redis started (127.0.0.1:6379)"
            return $result
        }

        if ($attempt -lt $maxRetries) {
            & $LogCallback "  Port 6379 not ready, retrying..."
            & docker rm -f yami-redis 2>&1 | Out-Null
            Start-Sleep -Seconds 2
        }
    }

    # 5. 重试用尽后检查 Docker 容器状态
    $inspect = & docker inspect yami-redis --format '{{.State.Status}}' 2>&1
    & $LogCallback "Redis container status: $inspect"

    $result.Message = "Redis failed to start after $maxRetries attempts"
    & $LogCallback "Redis failed to start. Check Docker Desktop and try manually:"
    & $LogCallback "  docker run -d --name yami-redis -p 6379:6379 redis:5.0.4"
    return $result
}

function Start-BackendService {
    param(
        [ValidateSet("admin", "api")][string]$ServiceName,
        [string]$ProjectRoot,
        [scriptblock]$LogCallback,
        [int]$TimeoutSeconds = 90
    )
    if (-not $LogCallback) { $LogCallback = { param($m) } }

    $result = @{ Success = $false; Message = ""; Process = $null }
    $port = if ($ServiceName -eq "admin") { 8085 } else { 8086 }
    $jarDir = Join-Path $ProjectRoot "yami-shop-$ServiceName/target"
    $jarFile = Join-Path $jarDir "yami-shop-$ServiceName-0.0.1-SNAPSHOT.jar"

    $portCheck = Check-Port -Port $port
    if ($portCheck.InUse) {
        if ($portCheck.ProcessName -eq "java") {
            $result.Success = $true
            $result.Message = "$ServiceName already running (port $port)"
            & $LogCallback "$ServiceName already running (port $port)"
            return $result
        } else {
            $result.Message = "Port $port in use by $($portCheck.ProcessName)"
            & $LogCallback "Port $port in use by $($portCheck.ProcessName)"
            return $result
        }
    }

    if (-not (Test-Path $jarFile)) {
        $result.Message = "JAR not found: $jarFile"
        & $LogCallback "JAR not found: $jarFile. Build first."
        return $result
    }

    & $LogCallback "Starting $ServiceName backend (port $port)..."

    try {
        $jobName = "mall4j-$ServiceName"
        $jobScript = {
            param($JarPath, $Port)
            $logFile = Join-Path $env:TEMP "mall4j-$Port.log"
            $p = Start-Process -FilePath "java" -ArgumentList "-jar -Dspring.profiles.active=dev -Xms512m -Xmx512m `"$JarPath`"" `
                -NoNewWindow -PassThru -RedirectStandardOutput $logFile -RedirectStandardError $logFile
            $p.WaitForExit()
        }

        $job = Start-Job -Name $jobName -ScriptBlock $jobScript -ArgumentList $jarFile, $port
        $script:ServiceJobs[$ServiceName] = $job

        & $LogCallback "Waiting for $ServiceName (max ${TimeoutSeconds}s)..."
        $waitOk = Wait-ForPort -Port $port -TimeoutSeconds $TimeoutSeconds

        if ($waitOk) {
            $result.Success = $true
            $result.Message = "$ServiceName started"
            & $LogCallback "$ServiceName started (port $port)"
        } else {
            $result.Message = "$ServiceName start timeout"
            & $LogCallback "$ServiceName start timeout"
        }
    } catch {
        $result.Message = "$ServiceName error: $_"
        & $LogCallback "$ServiceName error: $_"
    }
    return $result
}

function Start-FrontendService {
    param(
        [ValidateSet("mall4v", "mall4uni")][string]$FrontendName,
        [string]$ProjectRoot,
        [scriptblock]$LogCallback,
        [int]$TimeoutSeconds = 120
    )
    if (-not $LogCallback) { $LogCallback = { param($m) } }

    $result = @{ Success = $false; Message = ""; Port = 0 }
    $frontendDir = Join-Path $ProjectRoot "front-end/$FrontendName"
    $port = if ($FrontendName -eq "mall4v") { 9527 } else { 5173 }
    $pkgMgr = if ($FrontendName -eq "mall4v") { "pnpm" } else { "npm" }
    $devCmd = if ($FrontendName -eq "mall4v") { "pnpm dev" } else { "npm run dev" }

    $portCheck = Check-Port -Port $port
    if ($portCheck.InUse) {
        $result.Success = $true
        $result.Port = $port
        $result.Message = "$FrontendName already running (port $port)"
        & $LogCallback "$FrontendName already running (port $port)"
        return $result
    }

    if (-not (Test-Path $frontendDir)) {
        $result.Message = "Directory not found: $frontendDir"
        & $LogCallback "Directory not found: front-end/$FrontendName"
        return $result
    }

    $nodeModules = Join-Path $frontendDir "node_modules"
    if (-not (Test-Path $nodeModules)) {
        & $LogCallback "Installing $FrontendName dependencies..."
        try {
            $installProc = Start-Process -FilePath $pkgMgr -ArgumentList "--prefix", $frontendDir, "install" `
                -NoNewWindow -PassThru -Wait -RedirectStandardOutput "$env:TEMP\${FrontendName}_install.log" `
                -RedirectStandardError "$env:TEMP\${FrontendName}_install_err.log"
            if ($installProc.ExitCode -ne 0) {
                $result.Message = "Dependency install failed"
                & $LogCallback "Dependency install failed for $FrontendName"
                return $result
            }
            & $LogCallback "Dependencies installed for $FrontendName"
        } catch {
            $result.Message = "Install error: $_"
            & $LogCallback "Install error for ${FrontendName}: $_"
            return $result
        }
    }

    & $LogCallback "Starting $FrontendName dev server (port $port)..."

    try {
        $jobName = "frontend-$FrontendName"
        $jobScript = {
            param($Dir)
            Set-Location $Dir
            $logFile = Join-Path $env:TEMP "mall4j-frontend.log"
            $p = Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -Command `"& {pnpm dev}`"" -NoNewWindow -PassThru
            $p.WaitForExit()
        }

        $job = Start-Job -Name $jobName -ScriptBlock $jobScript -ArgumentList $frontendDir
        $script:ServiceJobs[$jobName] = $job

        $waitOk = Wait-ForPort -Port $port -TimeoutSeconds $TimeoutSeconds
        if ($waitOk) {
            $result.Success = $true
            $result.Port = $port
            $result.Message = "$FrontendName started"
            & $LogCallback "$FrontendName started (http://localhost:$port)"
        } else {
            $result.Message = "$FrontendName start timeout"
            & $LogCallback "$FrontendName start timeout (${TimeoutSeconds}s)"
        }
    } catch {
        $result.Message = "$FrontendName error: $_"
        & $LogCallback "$FrontendName error: $_"
    }
    return $result
}

function Test-JarsExist {
    param([string]$ProjectRoot)
    $adminJar = Join-Path $ProjectRoot "yami-shop-admin/target/yami-shop-admin-0.0.1-SNAPSHOT.jar"
    $apiJar   = Join-Path $ProjectRoot "yami-shop-api/target/yami-shop-api-0.0.1-SNAPSHOT.jar"
    $adminExists = Test-Path $adminJar
    $apiExists   = Test-Path $apiJar
    return @{ AdminExists = $adminExists; ApiExists = $apiExists; AllExist = ($adminExists -and $apiExists) }
}

function Invoke-MavenBuild {
    param(
        [string]$ProjectRoot,
        [string]$Module = "",
        [scriptblock]$LogCallback,
        [int]$TimeoutSeconds = 300
    )
    if (-not $LogCallback) { $LogCallback = { param($m) } }

    $result = @{ Success = $false; Message = ""; Duration = 0 }
    $mvnArgs = @("clean", "package", "-DskipTests")
    if ($Module) {
        $mvnArgs = @("clean", "package", "-pl", "yami-shop-$Module", "-am", "-DskipTests")
    }

    $moduleLabel = if ($Module) { $Module } else { "all modules" }
    & $LogCallback "Building backend ($moduleLabel)..."
    & $LogCallback "  mvn $($mvnArgs -join ' ')"

    $startTime = Get-Date
    $logFile = "$env:TEMP\mall4j_maven_build.log"

    try {
        $proc = Start-Process -FilePath "mvn" -ArgumentList $mvnArgs `
            -NoNewWindow -PassThru -WorkingDirectory $ProjectRoot `
            -RedirectStandardOutput $logFile -RedirectStandardError "${logFile}.err"
        $proc.WaitForExit($TimeoutSeconds * 1000)

        $duration = [int]((Get-Date) - $startTime).TotalSeconds
        $result.Duration = $duration

        if ($proc.ExitCode -eq 0) {
            $result.Success = $true
            $result.Message = "Build OK (${duration}s)"
            & $LogCallback "Build OK (${duration}s)"
        } else {
            & $LogCallback "Build FAILED"
            Get-Content $logFile -Tail 10 -ErrorAction SilentlyContinue | ForEach-Object { & $LogCallback "  $_" }
            $result.Message = "Build failed"
        }
    } catch {
        $result.Message = "Build error: $_"
        & $LogCallback "Build error: $_"
    }
    return $result
}

function Import-Database {
    param(
        [string]$ProjectRoot,
        [string]$User = "root",
        [string]$Password = "",
        [scriptblock]$LogCallback
    )
    if (-not $LogCallback) { $LogCallback = { param($m) } }

    $result = @{ Success = $false; Message = "" }
    $sqlFile = Join-Path $ProjectRoot "db/yami_shop.sql"

    if (-not (Test-Path $sqlFile)) {
        $result.Message = "SQL file not found: $sqlFile"
        & $LogCallback "SQL file not found: db/yami_shop.sql"
        return $result
    }

    $mysqlExe = Find-MySqlClient
    if (-not $mysqlExe) {
        $result.Message = "mysql client not found. Import manually: db/yami_shop.sql"
        & $LogCallback "mysql client not found. Import db/yami_shop.sql manually."
        return $result
    }

    & $LogCallback "Importing database yami_shops..."

    try {
        & $mysqlExe "-u$User" "-p$Password" -e "CREATE DATABASE IF NOT EXISTS `yami_shops` DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_general_ci" 2>&1 | Out-Null

        $importProc = Start-Process -FilePath $mysqlExe -ArgumentList "-u$User", "-p$Password", "yami_shops" `
            -NoNewWindow -PassThru -RedirectStandardInput $sqlFile `
            -RedirectStandardOutput "$env:TEMP\mysql_import.log" -RedirectStandardError "$env:TEMP\mysql_import_err.log"
        $importProc.WaitForExit(120000)

        if ($importProc.ExitCode -eq 0) {
            $result.Success = $true
            $result.Message = "Database imported"
            & $LogCallback "Database yami_shops imported"
        } else {
            $errMsg = Get-Content "$env:TEMP\mysql_import_err.log" -Raw -ErrorAction SilentlyContinue
            $result.Message = "Import failed: $errMsg"
            & $LogCallback "Import failed: $errMsg"
        }
    } catch {
        $result.Message = "Import error: $_"
        & $LogCallback "Import error: $_"
    }
    return $result
}

function Stop-AllServices {
    param([scriptblock]$LogCallback)
    if (-not $LogCallback) { $LogCallback = { param($m) } }
    & $LogCallback "Stopping all services..."

    @("admin", "api").ForEach({
        if ($script:ServiceJobs.ContainsKey($_)) {
            Stop-Job -Job $script:ServiceJobs[$_] -ErrorAction SilentlyContinue
            Remove-Job -Job $script:ServiceJobs[$_] -ErrorAction SilentlyContinue
        }
    })

    @("frontend-mall4v", "frontend-mall4uni").ForEach({
        if ($script:ServiceJobs.ContainsKey($_)) {
            Stop-Job -Job $script:ServiceJobs[$_] -ErrorAction SilentlyContinue
            Remove-Job -Job $script:ServiceJobs[$_] -ErrorAction SilentlyContinue
        }
    })

    $javaProcs = Get-Process -Name "java" -ErrorAction SilentlyContinue | Where-Object {
        try { $_.CommandLine -match "yami-shop" } catch { $false }
    }
    if ($javaProcs) {
        $javaProcs | Stop-Process -Force -ErrorAction SilentlyContinue
        & $LogCallback "Stopped $($javaProcs.Count) Java process(es)"
    }
    & $LogCallback "All services stopped"
}

# ===== 项目端口定义 =====
$script:ProjectPorts = @{
    "Redis"      = 6379
    "Admin"      = 8085
    "API"        = 8086
    "mall4v"     = 9527
    "mall4uni"   = 5173
}

function Get-ServiceStatus {
    <#
    .SYNOPSIS
        检测项目各服务当前运行状态（基于端口监听 + 进程名）
    #>
    $status = @{}
    foreach ($svc in $script:ProjectPorts.Keys) {
        $port = $script:ProjectPorts[$svc]
        $check = Check-Port -Port $port
        $status[$svc] = @{
            Port        = $port
            Running     = $check.InUse
            ProcessName = $check.ProcessName
            Pid         = $check.Pid
        }
    }
    return $status
}

function Stop-ServiceOnPort {
    <#
    .SYNOPSIS
        强制终止占用指定端口的进程
    #>
    param(
        [int]$Port,
        [string]$ServiceLabel,
        [scriptblock]$LogCallback
    )
    $check = Check-Port -Port $Port
    if (-not $check.InUse) {
        & $LogCallback "  [$ServiceLabel] Port $Port — 未占用，跳过"
        return $false
    }
    if ($check.Pid) {
        try {
            $proc = Get-Process -Id $check.Pid -ErrorAction Stop
            & $LogCallback "  [$ServiceLabel] 终止进程 PID=$($check.Pid) ($($proc.ProcessName))..."
            $proc.Kill()
            $proc.WaitForExit(3000)
            & $LogCallback "  [$ServiceLabel] 已终止"
            return $true
        } catch {
            & $LogCallback "  [$ServiceLabel] 终止失败: $_，尝试 taskkill..."
            try {
                & taskkill /F /PID $check.Pid 2>&1 | Out-Null
                & $LogCallback "  [$ServiceLabel] taskkill 完成"
                return $true
            } catch {
                & $LogCallback "  [$ServiceLabel] taskkill 也失败: $_"
            }
        }
    }
    return $false
}

function Stop-AndReleaseAll {
    <#
    .SYNOPSIS
        全面关闭 ALL：状态检查 → 依次关闭服务 → 释放端口 → 解除占用
    .DESCRIPTION
        比 Stop-AllServices 更彻底：
          - 依次关闭 admin → api → mall4v → mall4uni
          - 停止 Redis Docker 容器
          - 按端口强制释放（taskkill /F）
          - 最终残留进程清扫
    #>
    param([scriptblock]$LogCallback)
    if (-not $LogCallback) { $LogCallback = { param($m) } }

    # ---------------------------------------------------------------
    # Phase 1: 状态检查
    # ---------------------------------------------------------------
    & $LogCallback "====== 启动全面关闭 ======"
    & $LogCallback ""
    & $LogCallback "[Phase 1/5] 检查各服务运行状态..."
    $status = Get-ServiceStatus
    $runningCount = 0
    foreach ($svc in $status.Keys) {
        $info = $status[$svc]
        $flag = if ($info.Running) { "● 运行中" } else { "○ 空闲" }
        $extra = if ($info.Pid) { " (PID=$($info.Pid), $($info.ProcessName))" } else { "" }
        & $LogCallback "  $flag  $svc :$($info.Port)$extra"
        if ($info.Running) { $runningCount++ }
    }
    if ($runningCount -eq 0) {
        & $LogCallback "  没有服务在运行，无需关闭"
        & $LogCallback ""
        & $LogCallback "====== 全面关闭完成（无需操作） ======"
        & $LogCallback "//已终结商城程序，完成端口的释放"
        return
    }
    & $LogCallback "  共 $runningCount 个服务/端口需要关闭"
    & $LogCallback ""

    # ---------------------------------------------------------------
    # Phase 2: 关闭 Java 后端 (admin → api)
    # ---------------------------------------------------------------
    & $LogCallback "[Phase 2/5] 关闭后端服务..."
    # 先杀匹配 yami-shop 的 java 进程（覆盖 admin 和 api）
    $javaProcs = Get-Process -Name "java" -ErrorAction SilentlyContinue | Where-Object {
        try { $_.CommandLine -match "yami-shop" } catch { $false }
    }
    if ($javaProcs) {
        foreach ($proc in $javaProcs) {
            & $LogCallback "  终止 Java 后端 PID=$($proc.Id) (yami-shop)..."
            try { $proc.Kill(); $proc.WaitForExit(3000) } catch {}
        }
        & $LogCallback "  已终止 $($javaProcs.Count) 个 Java 后端进程"
    } else {
        & $LogCallback "  未发现运行中的 Java 后端进程"
    }

    # 再按端口确认释放
    Stop-ServiceOnPort -Port 8085 -ServiceLabel "Admin(8085)" -LogCallback $LogCallback | Out-Null
    Stop-ServiceOnPort -Port 8086 -ServiceLabel "API(8086)" -LogCallback $LogCallback | Out-Null
    & $LogCallback ""

    # ---------------------------------------------------------------
    # Phase 3: 通过进程父子关系杀前端整棵树（node→parent cmd/npm/pnpm）
    # ---------------------------------------------------------------
    & $LogCallback "[Phase 3/5] 终止前端进程树..."
    $frontKilled = 0
    $frontendPorts = @{9527 = "mall4v"; 5173 = "mall4uni"}
    foreach ($port in $frontendPorts.Keys) {
        $svcLabel = $frontendPorts[$port]
        $check = Check-Port -Port $port
        if ($check.InUse -and $check.Pid) {
            try {
                $parentPid = (Get-CimInstance Win32_Process -Filter "ProcessId=$($check.Pid)" -ErrorAction Stop).ParentProcessId
                if ($parentPid -and $parentPid -gt 0) {
                    & $LogCallback ("  终止 " + $svcLabel + " 进程树: 父 PID=" + $parentPid + " (子 node PID=" + $check.Pid + ")")
                    & taskkill /F /T /PID $parentPid 2>&1 | Out-Null
                    $frontKilled++
                    continue
                }
            } catch {
                & $LogCallback ("  WMI 查询失败 " + $svcLabel + " PID=" + $check.Pid + ": " + $_)
            }
            Stop-ServiceOnPort -Port $port -ServiceLabel "$svcLabel($port)" -LogCallback $LogCallback | Out-Null
            $frontKilled++
        } else {
            & $LogCallback ("  " + $svcLabel + "(:" + $port + ") 已空闲")
        }
    }
    if ($frontKilled -gt 0) {
        & $LogCallback ("  已终止 " + $frontKilled + " 个前端进程树")
    } else {
        & $LogCallback "  未找到前端进程"
    }
    & $LogCallback ""

    # ---------------------------------------------------------------
    # Phase 4: 停止 Redis Docker 容器
    # ---------------------------------------------------------------
    & $LogCallback "[Phase 4/5] 停止 Redis Docker 容器..."
    try {
        $redisContainer = & docker ps -a --filter "name=yami-redis" --format "{{.ID}}" 2>&1
        if ($redisContainer) {
            & $LogCallback "  发现 Redis 容器 ($redisContainer)，正在停止并移除..."
            & docker rm -f yami-redis 2>&1 | Out-Null
            & $LogCallback "  Redis 容器已移除"
        } else {
            & $LogCallback "  未发现 Redis 容器 (yami-redis)"
        }
    } catch {
        & $LogCallback "  Docker 操作失败（可能 Docker 未运行）: $_"
    }
    & $LogCallback ""

    # ---------------------------------------------------------------
    # Phase 5: 最终端口扫描 + 强制释放
    # ---------------------------------------------------------------
    & $LogCallback "[Phase 5/5] 最终扫描 + 强制释放所有项目及 Vite HMR 端口..."
    $stillBusy = @()
    $allPorts = @{}
    foreach ($kv in $script:ProjectPorts.GetEnumerator()) { $allPorts[$kv.Key] = $kv.Value }
    $allPorts["mall4v-hmr1"] = 9528; $allPorts["mall4v-hmr2"] = 9529; $allPorts["mall4v-hmr3"] = 9530
    $allPorts["mall4uni-hmr1"] = 5174; $allPorts["mall4uni-hmr2"] = 5175
    foreach ($svc in $allPorts.Keys) {
        $port = $allPorts[$svc]
        $check = Check-Port -Port $port
        if ($check.InUse) {
            & $LogCallback "  ⚠ $svc(:$port) 仍被 $($check.ProcessName)(PID=$($check.Pid)) 占用，强制释放..."
            try {
                & taskkill /F /PID $check.Pid 2>&1 | Out-Null
                Start-Sleep -Milliseconds 500
                $recheck = Check-Port -Port $port
                if ($recheck.InUse) {
                    & $LogCallback "  ✗ $svc(:$port) 释放失败"
                    $stillBusy += $svc
                } else {
                    & $LogCallback "  ✓ $svc(:$port) 已释放"
                }
            } catch {
                & $LogCallback "  ✗ $svc(:$port) 强制释放出错: $_"
                $stillBusy += $svc
            }
        } else {
            & $LogCallback "  ✓ $svc(:$port) — 空闲"
        }
    }
    & $LogCallback ""

    # ---------------------------------------------------------------
    # Phase 5b: 补杀残留 node/vite（按命令行匹配）+ 辅助端口
    # ---------------------------------------------------------------
    & $LogCallback "[Phase 5/5b] 清理残留进程..."
    $nodeKilled = 0

    function Test-IsFrontendProc {
        param([int]$Pid)
        try {
            $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$Pid" -ErrorAction Stop).CommandLine
            if (-not $cmdLine) { return $false }
            if ($cmdLine -match "front-end[\\/]mall4v" -or $cmdLine -match "front-end[\\/]mall4uni") { return $true }
            if ($cmdLine -match "mall4v" -or $cmdLine -match "mall4uni") { return $true }
        } catch {}
        return $false
    }

    foreach ($cname in @("node", "vite")) {
        Get-Process -Name $cname -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                if (Test-IsFrontendProc -Pid $_.Id) {
                    & $LogCallback ("  终止残留 " + $cname + " PID=" + $_.Id)
                    & taskkill /F /PID $_.Id 2>&1 | Out-Null
                    $nodeKilled++
                }
            } catch {}
        }
    }

    foreach ($auxPort in @(9528,9529,9530,5174,5175)) {
        $check = Check-Port -Port $auxPort
        if ($check.InUse -and $check.Pid) {
            & $LogCallback ("  释放辅助端口 " + $auxPort + " (PID=" + $check.Pid + ")")
            & taskkill /F /PID $check.Pid 2>&1 | Out-Null
            $nodeKilled++
        }
    }
    }
    # 第 3 步：按辅助端口补杀
    foreach ($auxPort in @(9528,9529,9530,5174,5175)) {
        $check = Check-Port -Port $auxPort
        if ($check.InUse -and $check.Pid) {
            & $LogCallback ("  释放辅助端口 " + $auxPort + " (PID=" + $check.Pid + ")")
            & taskkill /F /PID $check.Pid 2>&1 | Out-Null
            $nodeKilled++
        }
    }
    if ($nodeKilled -gt 0) {
        & $LogCallback ("  已清理 " + $nodeKilled + " 个残留 node 进程")
    } else {
        & $LogCallback "  无残留 node 进程"
    }
    & $LogCallback ""

    # ---------------------------------------------------------------
    # 总结
    # ---------------------------------------------------------------
    if ($stillBusy.Count -eq 0) {
        & $LogCallback "====== 全面关闭完成！所有端口已释放 ======"
        & $LogCallback "//已终结商城程序，完成端口的释放"
    } else {
        & $LogCallback "====== 全面关闭完成，但以下端口仍被占用 ======"
        & $LogCallback "//已终结商城程序，完成端口的释放（部分端口未释放）"
        foreach ($s in $stillBusy) {
            & $LogCallback "   ✗ $s :$($script:ProjectPorts[$s])"
        }
        & $LogCallback "请手动检查（管理员权限下运行: netstat -ano | findstr :PORT）"
    }
}

