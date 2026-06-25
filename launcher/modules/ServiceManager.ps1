# ServiceManager.ps1 - Service management module

$script:ServiceJobs = @{}

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

    $portCheck = Check-Port -Port 6379
    if ($portCheck.InUse) {
        $result.Success = $true
        $result.Message = "Redis already running (port 6379)"
        return $result
    }

    try {
        & $LogCallback "Starting Redis (Docker)..."
        & docker rm -f yami-redis 2>&1 | Out-Null
        $proc = Start-Process -FilePath "docker" -ArgumentList "run -d --name yami-redis -p 6379:6379 redis:5.0.4" `
            -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\redis_start.log" -RedirectStandardError "$env:TEMP\redis_start_err.log"
        if (-not $proc) {
            & $LogCallback "Redis: failed to create docker process"
            $result.Message = "Failed to create docker process"
            return $result
        }
        $proc.WaitForExit(15000)

        if ($proc.ExitCode -ne 0) {
            $errMsg = Get-Content "$env:TEMP\redis_start_err.log" -Raw -ErrorAction SilentlyContinue
            & $LogCallback "Redis start failed: $errMsg"
            $result.Message = "Redis start failed"
            return $result
        }

        $waitOk = Wait-ForPort -Port 6379 -TimeoutSeconds 15
        if ($waitOk) {
            $result.Success = $true
            $result.Message = "Redis started"
            & $LogCallback "Redis started (127.0.0.1:6379)"
        } else {
            $result.Message = "Redis port not listening"
            & $LogCallback "Redis start timeout"
        }
    } catch {
        $result.Message = "Redis error: $_"
        & $LogCallback "Redis error: $_"
    }
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

