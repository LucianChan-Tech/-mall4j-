<#
.SYNOPSIS
    Mall4j Launch Core - runs in background runspace
    All UI functions have null checks. Uses throw for abort.
#>

param(
    [string]$ProjectRoot,
    [string]$MysqlUser,
    [string]$MysqlPass,
    $Window
)

# Reload modules in runspace (内联以避免执行策略限制)
$script:ServiceJobs = @{}

# --- 内联 EnvCheck.ps1 ---
function Test-CommandExists { param([string]$Command) $oldPreference = $ErrorActionPreference; $ErrorActionPreference = 'Stop'; try { if (Get-Command $Command -ErrorAction Stop) { return $true } } catch { return $false } finally { $ErrorActionPreference = $oldPreference } }
function Find-MySqlClient { $paths = @("$env:ProgramFiles\MySQL\MySQL Server 8.0\bin\mysql.exe","$env:ProgramFiles\MySQL\MySQL Server 8.4\bin\mysql.exe","$env:ProgramFiles\MySQL\MySQL Server 9.0\bin\mysql.exe","$env:ProgramFiles(x86)\MySQL\MySQL Server 8.0\bin\mysql.exe","${env:ProgramFiles}\MySQL\MySQL Server 5.7\bin\mysql.exe"); foreach ($p in $paths) { if (Test-Path $p) { return $p } }; if (Test-CommandExists "mysql") { return "mysql" }; return $null }
function Check-JDK { $result = @{ Installed = $false; Version = $null; Path = $null; Ok = $false }; try { $javaOut = & java -version 2>&1; $versionStr = ($javaOut -join "`n"); if ($versionStr -match '"(\d+)\.?(\d+)?') { $majorVer = [int]$matches[1]; $result.Installed = $true; $result.Version = $majorVer; $result.Path = (Get-Command java).Source; $result.Ok = $majorVer -ge 17 } } catch {}; return $result }
function Check-Maven { $result = @{ Installed = $false; Version = $null; Ok = $false }; try { $mvnOut = & mvn --version 2>&1; $firstLine = ($mvnOut -join "`n"); if ($firstLine -match 'Apache Maven (\S+)') { $result.Installed = $true; $result.Version = $matches[1]; $result.Ok = $true } } catch {}; return $result }
function Check-NodeJS { $result = @{ Installed = $false; Version = $null; Ok = $false }; try { $nodeOut = & node --version 2>&1; $verStr = "$nodeOut".Trim(); if ($verStr -match 'v?(\d+)') { $majorVer = [int]$matches[1]; $result.Installed = $true; $result.Version = $verStr; $result.Ok = $majorVer -ge 18 } } catch {}; return $result }
function Check-Docker { $result = @{ Running = $false; Info = $null; Ok = $false }; try { $dockerOut = & docker info 2>&1; $output = "$dockerOut"; if ($output -match '(?i)(Server Version|Containers:)') { $result.Running = $true; $result.Ok = $true; $result.Info = "Docker is running" } elseif ($output -match 'docker desktop') { $result.Running = $false; $result.Info = "Docker Desktop not started" } else { $result.Running = $false; $result.Info = "Docker not available" } } catch { $result.Running = $false; $result.Info = "Docker not available" }; return $result }
function Check-Port { param([int]$Port) $result = @{ InUse = $false; ProcessName = $null; Pid = $null }; try { $lines = netstat -ano | Select-String ":$Port\s" | Select-String "LISTEN|听.*$|ESCUCH|ECOUTE|LAUSCHE"; $conn = $lines | Select-Object -First 1; if ($conn) { $result.InUse = $true; $line = $conn.Line -split '\s+'; if ($line.Count -ge 5) { $result.Pid = [int]$line[-1]; try { $proc = Get-Process -Id $result.Pid -ErrorAction Stop; $result.ProcessName = $proc.ProcessName } catch { $result.ProcessName = "unknown" } } } } catch {}; return $result }
function Test-MySqlConnection { param([string]$User="root",[string]$Password="",[string]$DbHost="127.0.0.1",[int]$Port=3306) $result = @{ Success = $false; Message = $null; DatabaseExists = $false }; $portCheck = Check-Port -Port $Port; if (-not $portCheck.InUse) { $result.Message = "MySQL port $Port is not listening."; return $result }; $mysqlExe = Find-MySqlClient; if ($mysqlExe) { try { $testArgs = @("-u",$User,"-p$Password","-h",$DbHost,"-P","$Port","-e","SELECT 1"); $mysqlOut = & $mysqlExe $testArgs 2>&1; $output = "$mysqlOut"; if ($output -match "ERROR") { if ($output -match "Access denied") { $result.Message = "MySQL connection failed: wrong username or password" } elseif ($output -match "Can't connect") { $result.Message = "MySQL connection failed: cannot connect to $DbHost`:$Port" } else { $result.Message = "MySQL error" }; return $result }; $result.Success = $true; $dbCheck = & $mysqlExe @("-u",$User,"-p$Password","-h",$DbHost,"-P","$Port","-e","SHOW DATABASES LIKE 'yami_shops'") 2>&1; if ("$dbCheck" -match "yami_shops") { $result.DatabaseExists = $true; $result.Message = "MySQL connected, yami_shops exists" } else { $result.DatabaseExists = $false; $result.Message = "MySQL connected, but yami_shops database does not exist" }; return $result } catch { $result.Message = "MySQL check error: $_"; return $result } }; $result.Success = $true; $result.Message = "mysql client not found, but port $Port is listening"; return $result }
function Check-ProjectStructure { param([string]$ProjectRoot) $checks = @{}; $requiredPaths = @{"pom.xml"="Maven root config";"yami-shop-admin"="admin module";"yami-shop-api"="api module";"front-end/mall4v"="mall4v frontend";"front-end/mall4uni"="mall4uni frontend";"db/yami_shop.sql"="DB init script"}; $allOk = $true; foreach ($path in $requiredPaths.Keys) { $fullPath = Join-Path $ProjectRoot $path; $exists = Test-Path $fullPath; $checks[$path] = @{ Exists = $exists; Label = $requiredPaths[$path] }; if (-not $exists) { $allOk = $false } }; return @{ Ok = $allOk; Message = if ($allOk) {"Project structure OK"} else {"Project structure incomplete"}; Checks = $checks } }
function Get-FullEnvironmentReport { param([string]$ProjectRoot) return @{ JDK=Check-JDK; Maven=Check-Maven; NodeJS=Check-NodeJS; Docker=Check-Docker; Port3306=Check-Port -Port 3306; Port6379=Check-Port -Port 6379; Port8085=Check-Port -Port 8085; Port8086=Check-Port -Port 8086; Port9527=Check-Port -Port 9527; Port5173=Check-Port -Port 5173; Project=Check-ProjectStructure -ProjectRoot $ProjectRoot } }

# --- 内联 ServiceManager.ps1 (精简版，仅 launch-core 用到的函数) ---
function Wait-ForPort { param([int]$Port,[int]$TimeoutSeconds=60) $startTime=Get-Date; while((Get-Date)-lt $startTime.AddSeconds($TimeoutSeconds)) { $check=Check-Port -Port $Port; if($check.InUse){return $true}; Start-Sleep -Milliseconds 1000 }; return $false }
function Start-DockerDesktop { $dockerCheck = & docker info 2>&1; if ("$dockerCheck" -match '(?i)(Server Version|Containers:)') { return $true }; $knownPaths = @("$env:ProgramFiles\Docker\Docker\Docker Desktop.exe","$env:ProgramFiles\Docker\Docker\Docker Desktop.exe","${env:ProgramFiles(x86)}\Docker\Docker\Docker Desktop.exe","$env:LOCALAPPDATA\Docker\Docker Desktop.exe","$env:ProgramW6432\Docker\Docker\Docker Desktop.exe"); $dockerExe = $null; foreach ($p in $knownPaths) { if (Test-Path $p) { $dockerExe = $p; break } }; if (-not $dockerExe) { $startMenu = [Environment]::GetFolderPath('CommonStartMenu'); $shortcut = Get-ChildItem -Path "$startMenu\*" -Recurse -Include "Docker Desktop.lnk" -ErrorAction SilentlyContinue | Select-Object -First 1; if ($shortcut) { $dockerExe = $shortcut.FullName } }; if (-not $dockerExe -and (Get-Command docker -ErrorAction SilentlyContinue)) { $dockerCmd = (Get-Command docker).Source; $dockerExe = Join-Path (Split-Path $dockerCmd -Parent) "Docker Desktop.exe"; if (-not (Test-Path $dockerExe)) { $dockerExe = $null } }; if (-not $dockerExe) { return $false }; try { $proc = Start-Process -FilePath $dockerExe -WindowStyle Hidden -PassThru; return $true } catch { return $false } }
function Wait-ForDockerDaemon { param([int]$TimeoutSeconds=60) $startTime=Get-Date; while((Get-Date)-lt $startTime.AddSeconds($TimeoutSeconds)) { $dockerCheck = & docker info 2>&1; if ("$dockerCheck" -match '(?i)(Server Version|Containers:)') { return $true }; Start-Sleep -Seconds 2 }; return $false }
function Test-PortListening { param([int]$Port) $lines = netstat -an 2>&1 | Select-String ":$Port\s" | Select-String "LISTEN|听|ESCUCH|ECOUTE|LAUSCHE"; return [bool]$lines }
function Start-RedisService { param([scriptblock]$LogCallback) if (-not $LogCallback) { $LogCallback = { param($m) } }; $result = @{ Success=$false; Message="" }; $portCheck=Check-Port -Port 6379; if ($portCheck.InUse) { $result.Success=$true; $result.Message="Redis already running (port 6379)"; & $LogCallback "Redis already running (port 6379)"; return $result }; if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { $result.Message = "Docker command not found."; & $LogCallback "Docker command not found."; return $result }; $dockerCheck = & docker info 2>&1; $dockerOk = "$dockerCheck" -match '(?i)(Server Version|Containers:)'; if (-not $dockerOk) { & $LogCallback "Docker Desktop not running, attempting to start..."; $started = Start-DockerDesktop; if ($started) { & $LogCallback "Docker Desktop launch initiated, waiting..."; $waited = Wait-ForDockerDaemon -TimeoutSeconds 60; if (-not $waited) { $result.Message = "Docker Desktop not ready within 60s"; & $LogCallback "Docker Desktop not ready within 60s"; return $result }; & $LogCallback "Docker Desktop is ready" } else { & $LogCallback "Could not find Docker Desktop."; $result.Message = "Docker Desktop not found."; return $result } }; & $LogCallback "Starting Redis (Docker)..."; $maxRetries=3; $attempt=0; while($attempt -lt $maxRetries) { $attempt++; & $LogCallback "  Attempt $attempt/$maxRetries..."; & docker rm -f yami-redis 2>&1 | Out-Null; & docker pull redis:5.0.4 2>&1 | Out-Null; & docker run -d --name yami-redis -p 6379:6379 redis:5.0.4 2>&1 | Out-Null; $waitStart=Get-Date; $portReady=$false; while((Get-Date)-lt $waitStart.AddSeconds(20)) { if(Test-PortListening -Port 6379){$portReady=$true;break}; Start-Sleep -Milliseconds 1000 }; if($portReady){$result.Success=$true;$result.Message="Redis started";& $LogCallback "Redis started (127.0.0.1:6379)";return $result}; if($attempt -lt $maxRetries){& $LogCallback "  Retrying...";& docker rm -f yami-redis 2>&1|Out-Null;Start-Sleep -Seconds 2} }; $inspect = & docker inspect yami-redis --format '{{.State.Status}}' 2>&1; & $LogCallback "Container status: $inspect"; $result.Message = "Redis failed after $maxRetries attempts"; & $LogCallback "Redis failed. Try manually: docker run -d --name yami-redis -p 6379:6379 redis:5.0.4"; return $result }
function Test-JarsExist { param([string]$ProjectRoot) $adminJar=Join-Path $ProjectRoot "yami-shop-admin/target/yami-shop-admin-0.0.1-SNAPSHOT.jar"; $apiJar=Join-Path $ProjectRoot "yami-shop-api/target/yami-shop-api-0.0.1-SNAPSHOT.jar"; return @{AllExist=((Test-Path $adminJar)-and(Test-Path $apiJar))} }
function Invoke-MavenBuild { param([string]$ProjectRoot,[string]$Module="",[scriptblock]$LogCallback,[int]$TimeoutSeconds=300) if(-not $LogCallback){$LogCallback={param($m)}}; $result=@{Success=$false;Message="";Duration=0}; $mvnArgs=@("clean","package","-DskipTests"); if($Module){$mvnArgs=@("clean","package","-pl","yami-shop-$Module","-am","-DskipTests")}; $moduleLabel=if($Module){$Module}else{"all modules"}; & $LogCallback "Building backend ($moduleLabel)..."; & $LogCallback "  mvn $($mvnArgs -join ' ')"; $startTime=Get-Date;$logFile="$env:TEMP\mall4j_maven_build.log"; try{$proc=Start-Process -FilePath "mvn" -ArgumentList $mvnArgs -NoNewWindow -PassThru -WorkingDirectory $ProjectRoot -RedirectStandardOutput $logFile -RedirectStandardError "${logFile}.err";$proc.WaitForExit($TimeoutSeconds*1000);$duration=[int]((Get-Date)-$startTime).TotalSeconds;$result.Duration=$duration;if($proc.ExitCode -eq 0){$result.Success=$true;$result.Message="Build OK (${duration}s)";& $LogCallback "Build OK (${duration}s)"}else{& $LogCallback "Build FAILED";Get-Content $logFile -Tail 10 -ErrorAction SilentlyContinue|ForEach-Object{& $LogCallback "  $_"};$result.Message="Build failed"}}catch{$result.Message="Build error: $_";& $LogCallback "Build error: $_"}; return $result }
function Start-BackendService { param([ValidateSet("admin","api")][string]$ServiceName,[string]$ProjectRoot,[string]$MysqlUser,[string]$MysqlPass,[scriptblock]$LogCallback,[int]$TimeoutSeconds=90) if(-not $LogCallback){$LogCallback={param($m)}}; $result=@{Success=$false;Message="";Process=$null}; $port=if($ServiceName -eq "admin"){8085}else{8086}; $jarDir=Join-Path $ProjectRoot "yami-shop-$ServiceName/target"; $jarFile=Join-Path $jarDir "yami-shop-$ServiceName-0.0.1-SNAPSHOT.jar"; $portCheck=Check-Port -Port $port; if($portCheck.InUse){if($portCheck.ProcessName -eq "java"){$result.Success=$true;$result.Message="$ServiceName already running (port $port)";& $LogCallback "$ServiceName already running (port $port)";return $result}else{$result.Message="Port $port in use by $($portCheck.ProcessName)";& $LogCallback "Port $port in use by $($portCheck.ProcessName)";return $result}}; if(-not (Test-Path $jarFile)){$result.Message="JAR not found: $jarFile";& $LogCallback "JAR not found: $jarFile. Build first.";return $result}; & $LogCallback "Starting $ServiceName backend (port $port)..."; try{$jobName="mall4j-$ServiceName"; $jobScript={param($JarPath,$Port,$MysqlUser,$MysqlPass)$logFile=Join-Path $env:TEMP "mall4j-$Port.log";$p=Start-Process -FilePath "java" -ArgumentList @("-jar","-Dspring.profiles.active=dev","-Dspring.datasource.username=$MysqlUser","-Dspring.datasource.password=$MysqlPass","-Xms512m","-Xmx512m","`"$JarPath`"") -NoNewWindow -PassThru -RedirectStandardOutput $logFile -RedirectStandardError $logFile;$p.WaitForExit()}; $job=Start-Job -Name $jobName -ScriptBlock $jobScript -ArgumentList $jarFile,$port,$MysqlUser,$MysqlPass; $script:ServiceJobs[$ServiceName]=$job; & $LogCallback "Waiting for $ServiceName (max ${TimeoutSeconds}s)..."; $waitOk=Wait-ForPort -Port $port -TimeoutSeconds $TimeoutSeconds; if($waitOk){$result.Success=$true;$result.Message="$ServiceName started";& $LogCallback "$ServiceName started (port $port)"}else{$result.Message="$ServiceName start timeout";& $LogCallback "$ServiceName start timeout"}}catch{$result.Message="$ServiceName error: $_";& $LogCallback "$ServiceName error: $_"}; return $result }
function Start-FrontendService { param([ValidateSet("mall4v","mall4uni")][string]$FrontendName,[string]$ProjectRoot,[scriptblock]$LogCallback,[int]$TimeoutSeconds=120) if(-not $LogCallback){$LogCallback={param($m)}}; $result=@{Success=$false;Message="";Port=0}; $frontendDir=Join-Path $ProjectRoot "front-end/$FrontendName"; $port=if($FrontendName -eq "mall4v"){9527}else{5173}; $pkgMgr=if($FrontendName -eq "mall4v"){"pnpm"}else{"npm"}; $portCheck=Check-Port -Port $port; if($portCheck.InUse){$result.Success=$true;$result.Port=$port;$result.Message="$FrontendName already running (port $port)";& $LogCallback "$FrontendName already running (port $port)";return $result}; if(-not (Test-Path $frontendDir)){$result.Message="Directory not found: $frontendDir";& $LogCallback "Directory not found: front-end/$FrontendName";return $result}; $nodeModules=Join-Path $frontendDir "node_modules"; if(-not (Test-Path $nodeModules)){& $LogCallback "Installing $FrontendName dependencies..."; try{$installProc=Start-Process -FilePath $pkgMgr -ArgumentList "--prefix",$frontendDir,"install" -NoNewWindow -PassThru -Wait -RedirectStandardOutput "$env:TEMP\${FrontendName}_install.log" -RedirectStandardError "$env:TEMP\${FrontendName}_install_err.log"; if($installProc.ExitCode -ne 0){$result.Message="Dependency install failed";& $LogCallback "Dependency install failed for $FrontendName";return $result}; & $LogCallback "Dependencies installed for $FrontendName"}catch{$result.Message="Install error: $_";& $LogCallback "Install error for ${FrontendName}: $_";return $result}}; & $LogCallback "Starting $FrontendName dev server (port $port)..."; try{$jobName="frontend-$FrontendName";$jobScript={param($Dir)Set-Location $Dir;$logFile=Join-Path $env:TEMP "mall4j-frontend.log";$p=Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -Command `"$devCmd`"" -NoNewWindow -PassThru;$p.WaitForExit()}; $job=Start-Job -Name $jobName -ScriptBlock $jobScript -ArgumentList $frontendDir;$script:ServiceJobs[$jobName]=$job; $waitOk=Wait-ForPort -Port $port -TimeoutSeconds $TimeoutSeconds; if($waitOk){$result.Success=$true;$result.Port=$port;$result.Message="$FrontendName started";& $LogCallback "$FrontendName started (http://localhost:$port)"}else{$result.Message="$FrontendName start timeout";& $LogCallback "$FrontendName start timeout (${TimeoutSeconds}s)"}}catch{$result.Message="$FrontendName error: $_";& $LogCallback "$FrontendName error: $_"}; return $result }
function Stop-AllServices { param([scriptblock]$LogCallback) if(-not $LogCallback){$LogCallback={param($m)}}; & $LogCallback "Stopping all services..."; @("admin","api").ForEach({if($script:ServiceJobs.ContainsKey($_)){Stop-Job -Job $script:ServiceJobs[$_]-ErrorAction SilentlyContinue;Remove-Job -Job $script:ServiceJobs[$_]-ErrorAction SilentlyContinue}}); @("frontend-mall4v","frontend-mall4uni").ForEach({if($script:ServiceJobs.ContainsKey($_)){Stop-Job -Job $script:ServiceJobs[$_]-ErrorAction SilentlyContinue;Remove-Job -Job $script:ServiceJobs[$_]-ErrorAction SilentlyContinue}}); $javaProcs=Get-Process -Name "java" -ErrorAction SilentlyContinue|Where-Object{try{$_.CommandLine -match "yami-shop"}catch{$false}}; if($javaProcs){$javaProcs|Stop-Process -Force -ErrorAction SilentlyContinue;& $LogCallback "Stopped $($javaProcs.Count) Java process(es)"}; & $LogCallback "All services stopped" }

# ===== UI helpers (safe null checks everywhere) =====

function Write-LogUI {
    param([string]$Message, [string]$Level = "INFO")
    if (-not $Window) { return }
    $Window.Dispatcher.Invoke([Action]{
        $c = $Window.FindName("txtLog")
        if (-not $c) { return }
        $ts = Get-Date -Format "HH:mm:ss"
        $c.AppendText("[$ts][$Level] $Message`n")
        try { $c.CaretIndex = $c.Text.Length; $c.ScrollToCaret() } catch {}
    }, "Normal")
}

function Set-StepUI {
    param([int]$Id, [string]$Status, [string]$Text)
    if (-not $Window) { return }
    $Window.Dispatcher.Invoke([Action]{
        $sl = $Window.FindName("stepList")
        if (-not $sl) { return }
        try { $item = $sl.Items[$Id] } catch { return }
        if (-not $item) { return }
        $item.Status = $Status
        $item.StatusText = $Text
        switch ($Status) {
            "completed" { $item.StatusColor = "#07C160"; $item.StatusIcon = "V"; $item.StatusTextColor = "#07C160" }
            "failed"    { $item.StatusColor = "#FA5151"; $item.StatusIcon = "X"; $item.StatusTextColor = "#FA5151" }
            "running"   { $item.StatusColor = "#07C160"; $item.StatusIcon = "~"; $item.StatusTextColor = "#07C160" }
            default     { $item.StatusColor = "#DDDDDD"; $item.StatusIcon = "o"; $item.StatusTextColor = "#999999" }
        }
        try { $sl.Items.Refresh() } catch {}
    }, "Normal")
}

function Set-StatusBarUI {
    param([string]$Text, [string]$Color = "#07C160")
    if (-not $Window) { return }
    $Window.Dispatcher.Invoke([Action]{
        $lbl = $Window.FindName("lblStatus")
        if (-not $lbl) { return }
        $lbl.Text = $Text
        $lbl.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Color)
    }, "Normal")
}

function Enable-ButtonsUI {
    param([bool]$Start, [bool]$Stop)
    if (-not $Window) { return }
    $Window.Dispatcher.Invoke([Action]{
        $bs = $Window.FindName("btnStart")
        $bp = $Window.FindName("btnStop")
        if ($bs) { $bs.IsEnabled = $Start }
        if ($bp) { $bp.IsEnabled = $Stop }
    }, "Normal")
}

function Show-MessageBoxUI {
    param([string]$Message, [string]$Title = "Info")
    if (-not $Window) { return }
    $Window.Dispatcher.Invoke([Action]{
        [System.Windows.MessageBox]::Show($Message, $Title) | Out-Null
    }, "Normal")
}

# ===== Log callback =====
$logCb = { param($m) Write-LogUI -Message $m -Level "INFO" }

try {
    # ===== Step 0: Environment Check =====
    Set-StepUI -Id 0 -Status "running" -Text "Checking..."
    Write-LogUI -Message "Checking environment..." -Level "INFO"
    $envReport = Get-FullEnvironmentReport -ProjectRoot $ProjectRoot

    Write-LogUI -Message "  JDK: $(if($envReport.JDK.Ok){'OK'}else{'FAIL'}) v$($envReport.JDK.Version)" -Level "INFO"
    Write-LogUI -Message "  Maven: $(if($envReport.Maven.Ok){'OK'}else{'FAIL'}) $($envReport.Maven.Version)" -Level "INFO"
    Write-LogUI -Message "  Node.js: $(if($envReport.NodeJS.Ok){'OK'}else{'FAIL'}) $($envReport.NodeJS.Version)" -Level "INFO"
    Write-LogUI -Message "  Docker: $(if($envReport.Docker.Ok){'OK'}else{'FAIL'})" -Level "INFO"
    Write-LogUI -Message "  Project: $(if($envReport.Project.Ok){'OK'}else{'FAIL'})" -Level "INFO"
    Write-LogUI -Message "  Redis(6379): $(if($envReport.Port6379.InUse){'InUse'}else{'Free'})" -Level "INFO"
    Write-LogUI -Message "  admin(8085): $(if($envReport.Port8085.InUse){'InUse'}else{'Free'})" -Level "INFO"
    Write-LogUI -Message "  api(8086):   $(if($envReport.Port8086.InUse){'InUse'}else{'Free'})" -Level "INFO"
    Set-StepUI -Id 0 -Status "completed" -Text "Done"

    # ===== Step 1: DB Connection =====
    Set-StepUI -Id 1 -Status "running" -Text "Connecting..."
    Write-LogUI -Message "Testing MySQL connection..." -Level "INFO"
    $dbResult = Test-MySqlConnection -User $MysqlUser -Password $MysqlPass

    if ($dbResult.Success) {
        Write-LogUI -Message "$($dbResult.Message)" -Level "SUCCESS"
        Set-StepUI -Id 1 -Status "completed" -Text "Connected"
        if (-not $dbResult.DatabaseExists) {
            Write-LogUI -Message "Database yami_shops not found, importing..." -Level "WARN"
            $importResult = Import-Database -ProjectRoot $ProjectRoot -User $MysqlUser -Password $MysqlPass -LogCallback $logCb
            if ($importResult.Success) {
                Write-LogUI -Message "Database imported successfully" -Level "SUCCESS"
            } else {
                Write-LogUI -Message "Import failed, please import manually: db/yami_shop.sql" -Level "ERROR"
                Set-StepUI -Id 1 -Status "failed" -Text "Import failed"
                Set-StatusBarUI -Text "DB import failed" -Color "#FA5151"
                Enable-ButtonsUI -Start $true -Stop $false
                throw "Abort: DB import failed"
            }
        }
    } else {
        Write-LogUI -Message "$($dbResult.Message)" -Level "ERROR"
        Write-LogUI -Message "Update MySQL credentials and retry" -Level "INFO"
        Set-StepUI -Id 1 -Status "failed" -Text "Connection failed"
        Set-StatusBarUI -Text "MySQL connection failed" -Color "#FA5151"
        Enable-ButtonsUI -Start $true -Stop $false
        throw "Abort: MySQL connection failed"
    }

    # ===== Step 2: Start Redis =====
    Set-StepUI -Id 2 -Status "running" -Text "Starting..."
    try {
        $redisPortCheck = Check-Port -Port 6379
        if ($redisPortCheck.InUse) {
            Write-LogUI -Message "Redis already running (port 6379)" -Level "SUCCESS"
            Set-StepUI -Id 2 -Status "completed" -Text "Already running"
        } else {
            $redisResult = Start-RedisService -LogCallback $logCb
            if ($redisResult.Success) {
                Set-StepUI -Id 2 -Status "completed" -Text "Started"
            } else {
                Write-LogUI -Message "Redis failed to start, check if Docker is running" -Level "WARN"
                Set-StepUI -Id 2 -Status "failed" -Text "Failed"
            }
        }
    } catch {
        Write-LogUI -Message "Step 2 error: $_" -Level "ERROR"
        Set-StepUI -Id 2 -Status "failed" -Text "Error"
    }

    # ===== Step 3: Build Backend =====
    # 先检查预编译 JAR 是否存在
    $jarsExist = Test-JarsExist -ProjectRoot $ProjectRoot
    if ($jarsExist.AllExist) {
        Write-LogUI -Message "Pre-built JARs found, skipping Maven build" -Level "SUCCESS"
        Set-StepUI -Id 3 -Status "completed" -Text "Skipped (JARs exist)"
    } else {
        Set-StepUI -Id 3 -Status "running" -Text "Building..."
        Set-StatusBarUI -Text "Building backend (~1-3 min)..." -Color "#FFC300"
        try {
            $mavenResult = Invoke-MavenBuild -ProjectRoot $ProjectRoot -LogCallback $logCb -TimeoutSeconds 300
        } catch {
            Write-LogUI -Message "Step 3 error: $_" -Level "ERROR"
            Set-StepUI -Id 3 -Status "failed" -Text "Error"
            Set-StatusBarUI -Text "Build failed" -Color "#FA5151"
            Enable-ButtonsUI -Start $true -Stop $false
            throw "Abort: Build exception"
        }
        if ($mavenResult.Success) {
            Write-LogUI -Message "Build successful ($($mavenResult.Duration)s)" -Level "SUCCESS"
            Set-StepUI -Id 3 -Status "completed" -Text "Build OK"
        } else {
            Write-LogUI -Message "Build failed, check code and retry" -Level "ERROR"
            Set-StepUI -Id 3 -Status "failed" -Text "Build failed"
            Set-StatusBarUI -Text "Build failed" -Color "#FA5151"
            Enable-ButtonsUI -Start $true -Stop $false
            throw "Abort: Build failed"
        }
    }

    # ===== Step 4: Start admin Backend =====
    Set-StepUI -Id 4 -Status "running" -Text "Starting..."
    Set-StatusBarUI -Text "Starting admin backend..." -Color "#07C160"
    try {
        $adminResult = Start-BackendService -ServiceName "admin" -ProjectRoot $ProjectRoot -MysqlUser $MysqlUser -MysqlPass $MysqlPass -LogCallback $logCb
    } catch {
        Write-LogUI -Message "Step 4 error: $_" -Level "ERROR"
        Set-StepUI -Id 4 -Status "failed" -Text "Error"
        throw "Abort: admin start failed"
    }
    if ($adminResult.Success) {
        Set-StepUI -Id 4 -Status "completed" -Text "Started"
    } else {
        Write-LogUI -Message "admin backend failed to start" -Level "ERROR"
        Set-StepUI -Id 4 -Status "failed" -Text "Failed"
    }

    # ===== Step 5: Start api Backend =====
    Set-StepUI -Id 5 -Status "running" -Text "Starting..."
    Set-StatusBarUI -Text "Starting api backend..." -Color "#07C160"
    try {
        $apiResult = Start-BackendService -ServiceName "api" -ProjectRoot $ProjectRoot -MysqlUser $MysqlUser -MysqlPass $MysqlPass -LogCallback $logCb
    } catch {
        Write-LogUI -Message "Step 5 error: $_" -Level "ERROR"
        Set-StepUI -Id 5 -Status "failed" -Text "Error"
        throw "Abort: api start failed"
    }
    if ($apiResult.Success) {
        Set-StepUI -Id 5 -Status "completed" -Text "Started"
    } else {
        Write-LogUI -Message "api backend failed to start" -Level "ERROR"
        Set-StepUI -Id 5 -Status "failed" -Text "Failed"
    }

    # ===== Step 6: Start mall4v Frontend =====
    Set-StepUI -Id 6 -Status "running" -Text "Starting..."
    Set-StatusBarUI -Text "Starting mall4v frontend..." -Color "#07C160"
    try {
        $mall4vResult = Start-FrontendService -FrontendName "mall4v" -ProjectRoot $ProjectRoot -LogCallback $logCb -TimeoutSeconds 120
    } catch {
        Write-LogUI -Message "Step 6 error: $_" -Level "ERROR"
        Set-StepUI -Id 6 -Status "failed" -Text "Error"
        throw "Abort: mall4v start failed"
    }
    if ($mall4vResult.Success) {
        Set-StepUI -Id 6 -Status "completed" -Text "Started"
    } else {
        Write-LogUI -Message "mall4v failed, manual: pnpm --prefix front-end/mall4v dev" -Level "WARN"
        Set-StepUI -Id 6 -Status "failed" -Text "Failed"
    }

    # ===== Step 7: Start mall4uni Frontend =====
    Set-StepUI -Id 7 -Status "running" -Text "Starting..."
    Set-StatusBarUI -Text "Starting mall4uni frontend..." -Color "#07C160"
    try {
        $mall4uniResult = Start-FrontendService -FrontendName "mall4uni" -ProjectRoot $ProjectRoot -LogCallback $logCb -TimeoutSeconds 120
    } catch {
        Write-LogUI -Message "Step 7 error: $_" -Level "ERROR"
        Set-StepUI -Id 7 -Status "failed" -Text "Error"
        throw "Abort: mall4uni start failed"
    }
    if ($mall4uniResult.Success) {
        Set-StepUI -Id 7 -Status "completed" -Text "Started"
    } else {
        Write-LogUI -Message "mall4uni failed, manual: npm --prefix front-end/mall4uni run dev" -Level "WARN"
        Set-StepUI -Id 7 -Status "failed" -Text "Failed"
    }

    # ===== Done =====
    $backendOk = $adminResult.Success -and $apiResult.Success
    if ($backendOk) {
        Write-LogUI -Message "" -Level "INFO"
        Write-LogUI -Message "==========================================" -Level "SUCCESS"
        Write-LogUI -Message "  Mall4j started successfully!" -Level "SUCCESS"
        Write-LogUI -Message "==========================================" -Level "SUCCESS"
        Write-LogUI -Message "  Admin UI:  http://localhost:9527 (admin/123456)" -Level "SUCCESS"
        Write-LogUI -Message "  Shop H5:   http://localhost:5173" -Level "SUCCESS"
        Write-LogUI -Message "  Admin API: http://127.0.0.1:8085" -Level "SUCCESS"
        Write-LogUI -Message "  Api API:   http://127.0.0.1:8086" -Level "SUCCESS"
        Write-LogUI -Message "  API Doc:   http://127.0.0.1:8085/doc.html" -Level "SUCCESS"
        Write-LogUI -Message "==========================================" -Level "SUCCESS"
        Set-StatusBarUI -Text "All services started!" -Color "#07C160"
        Show-MessageBoxUI -Message "Mall4j started!" -Title "Success"
    } else {
        Set-StatusBarUI -Text "Some services failed, check log" -Color "#FA5151"
    }

} catch {
    Write-LogUI -Message "Abort: $_" -Level "ERROR"
} finally {
    Enable-ButtonsUI -Start $true -Stop $false
}
