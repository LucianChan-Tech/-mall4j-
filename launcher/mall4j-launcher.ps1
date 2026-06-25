<#
.SYNOPSIS
    Mall4j Launcher - Main Script
.DESCRIPTION
    WPF GUI launcher for Mall4j dev environment
    Double-click mall4j-launcher.bat to run
#>

#=============================================
# 1. Init Paths (robust for both .ps1 and .exe)
#=============================================
# Try multiple methods to find the launcher directory
$script:ScriptDir = $null

# Method 1: Process location (works for compiled .exe from ps2exe)
try {
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $exeDir = [System.IO.Path]::GetDirectoryName($exePath)
    if (Test-Path (Join-Path $exeDir "mall4j-launcher.xaml")) {
        $script:ScriptDir = $exeDir
    }
} catch {}

# Method 2: PSScriptRoot (works for .ps1 scripts)
if (-not $script:ScriptDir -and $PSScriptRoot) {
    if (Test-Path (Join-Path $PSScriptRoot "mall4j-launcher.xaml")) {
        $script:ScriptDir = $PSScriptRoot
    }
}

# Method 3: MyInvocation
if (-not $script:ScriptDir -and $MyInvocation.MyCommand.Path) {
    $p = Split-Path $MyInvocation.MyCommand.Path -Parent
    if (Test-Path (Join-Path $p "mall4j-launcher.xaml")) {
        $script:ScriptDir = $p
    }
}

# Method 4: Current directory
if (-not $script:ScriptDir) {
    $p = (Get-Location).Path
    if (Test-Path (Join-Path $p "mall4j-launcher.xaml")) {
        $script:ScriptDir = $p
    }
}

if (-not $script:ScriptDir) {
    Write-Host "[FATAL] Cannot find launcher directory. Make sure Mall4jLauncher.exe is in the launcher/ folder."
    Write-Host "Looked in: exe dir, PSScriptRoot, MyInvocation, current dir"
    Read-Host "Press Enter to exit"
    exit 1
}

$script:ProjectRoot = Resolve-Path (Join-Path $script:ScriptDir "..")

# Validate project root
if (-not (Test-Path (Join-Path $script:ProjectRoot "pom.xml"))) {
    Write-Host "[ERROR] Project root not found (pom.xml)" -ForegroundColor Red
    Write-Host "Place launcher/ folder in mall4j project root" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# ===== 内联模块：EnvCheck.ps1 =====
function Test-CommandExists {
    param([string]$Command)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
    try {
        if (Get-Command $Command -ErrorAction Stop) { return $true }
    } catch { return $false }
    finally { $ErrorActionPreference = $oldPreference }
}

function Find-MySqlClient {
    $paths = @(
        "$env:ProgramFiles\MySQL\MySQL Server 8.0\bin\mysql.exe",
        "$env:ProgramFiles\MySQL\MySQL Server 8.4\bin\mysql.exe",
        "$env:ProgramFiles\MySQL\MySQL Server 9.0\bin\mysql.exe",
        "$env:ProgramFiles(x86)\MySQL\MySQL Server 8.0\bin\mysql.exe",
        "${env:ProgramFiles}\MySQL\MySQL Server 5.7\bin\mysql.exe"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }
    if (Test-CommandExists "mysql") { return "mysql" }
    return $null
}

function Check-JDK {
    $result = @{ Installed = $false; Version = $null; Path = $null; Ok = $false }
    try {
        $javaOut = & java -version 2>&1
        $versionStr = ($javaOut -join "`n")
        if ($versionStr -match '"(\d+)\.?(\d+)?') {
            $majorVer = [int]$matches[1]
            $result.Installed = $true
            $result.Version = $majorVer
            $result.Path = (Get-Command java).Source
            $result.Ok = $majorVer -ge 17
        }
    } catch { $result.Installed = $false }
    return $result
}

function Check-Maven {
    $result = @{ Installed = $false; Version = $null; Ok = $false }
    try {
        $mvnOut = & mvn --version 2>&1
        $firstLine = ($mvnOut -join "`n")
        if ($firstLine -match 'Apache Maven (\S+)') {
            $result.Installed = $true
            $result.Version = $matches[1]
            $result.Ok = $true
        }
    } catch { $result.Installed = $false }
    return $result
}

function Check-NodeJS {
    $result = @{ Installed = $false; Version = $null; Ok = $false }
    try {
        $nodeOut = & node --version 2>&1
        $verStr = "$nodeOut".Trim()
        if ($verStr -match 'v?(\d+)') {
            $majorVer = [int]$matches[1]
            $result.Installed = $true
            $result.Version = $verStr
            $result.Ok = $majorVer -ge 18
        }
    } catch { $result.Installed = $false }
    return $result
}

function Check-Pnpm {
    $result = @{ Installed = $false; Version = $null; Ok = $false }
    try {
        $pnpmOut = & pnpm --version 2>&1
        $result.Installed = $true
        $result.Version = "$pnpmOut".Trim()
        $result.Ok = $true
    } catch { $result.Installed = $false }
    return $result
}

function Check-Docker {
    $result = @{ Running = $false; Info = $null; Ok = $false }
    try {
        $dockerOut = & docker info 2>&1
        $output = "$dockerOut"
        if ($output -match '(?i)(Server Version|Containers:)') {
            $result.Running = $true
            $result.Ok = $true
            $result.Info = "Docker is running"
        } elseif ($output -match 'docker desktop') {
            $result.Running = $false
            $result.Info = "Docker Desktop not started"
        } else {
            $result.Running = $false
            $result.Info = "Docker not available"
        }
    } catch {
        $result.Running = $false
        $result.Info = "Docker not available"
    }
    return $result
}

function Check-Port {
    param([int]$Port)
    $result = @{ InUse = $false; ProcessName = $null; Pid = $null }
    try {
        $lines = netstat -ano | Select-String ":$Port\s" | Select-String "LISTEN|听.*$|ESCUCH|ECOUTE|LAUSCHE"
        $conn = $lines | Select-Object -First 1
        if ($conn) {
            $result.InUse = $true
            $line = $conn.Line -split '\s+'
            if ($line.Count -ge 5) {
                $result.Pid = [int]$line[-1]
                try {
                    $proc = Get-Process -Id $result.Pid -ErrorAction Stop
                    $result.ProcessName = $proc.ProcessName
                } catch { $result.ProcessName = "unknown" }
            }
        }
    } catch {}
    return $result
}

function Test-MySqlConnection {
    param(
        [string]$User = "root",
        [string]$Password = "",
        [string]$DbHost = "127.0.0.1",
        [int]$Port = 3306
    )
    $result = @{ Success = $false; Message = $null; DatabaseExists = $false }
    $portCheck = Check-Port -Port $Port
    if (-not $portCheck.InUse) {
        $result.Message = "MySQL port $Port is not listening. Make sure MySQL is running."
        return $result
    }
    $mysqlExe = Find-MySqlClient
    if ($mysqlExe) {
        try {
            $testArgs = @("-u", $User, "-p$Password", "-h", $DbHost, "-P", "$Port", "-e", "SELECT 1")
            $mysqlOut = & $mysqlExe $testArgs 2>&1
            $output = "$mysqlOut"
            if ($output -match "ERROR") {
                if ($output -match "Access denied") {
                    $result.Message = "MySQL connection failed: wrong username or password"
                } elseif ($output -match "Can't connect") {
                    $result.Message = "MySQL connection failed: cannot connect to $DbHost`:$Port"
                } else {
                    $trimmed = $output.Substring(0, [Math]::Min(100, $output.Length))
                    $result.Message = "MySQL error: $trimmed"
                }
                return $result
            }
            $result.Success = $true
            $dbCheck = & $mysqlExe @("-u", $User, "-p$Password", "-h", $DbHost, "-P", "$Port", "-e", "SHOW DATABASES LIKE 'yami_shops'") 2>&1
            if ("$dbCheck" -match "yami_shops") {
                $result.DatabaseExists = $true
                $result.Message = "MySQL connected, database yami_shops exists"
            } else {
                $result.DatabaseExists = $false
                $result.Message = "MySQL connected, but yami_shops database does not exist"
            }
            return $result
        } catch {
            $result.Message = "MySQL check error: $_"
            return $result
        }
    }
    $result.Success = $true
    $result.Message = "mysql client not found, but port $Port is listening (verify credentials manually)"
    return $result
}

function Check-ProjectStructure {
    param([string]$ProjectRoot)
    $checks = @{}
    $requiredPaths = @{
        "pom.xml"               = "Maven root config"
        "yami-shop-admin"       = "admin module"
        "yami-shop-api"         = "api module"
        "front-end/mall4v"      = "mall4v frontend"
        "front-end/mall4uni"    = "mall4uni frontend"
        "db/yami_shop.sql"      = "DB init script"
    }
    $allOk = $true
    foreach ($path in $requiredPaths.Keys) {
        $fullPath = Join-Path $ProjectRoot $path
        $exists = Test-Path $fullPath
        $checks[$path] = @{ Exists = $exists; Label = $requiredPaths[$path] }
        if (-not $exists) { $allOk = $false }
    }
    return @{ Ok = $allOk; Message = if ($allOk) { "Project structure OK" } else { "Project structure incomplete" }; Checks = $checks }
}

function Get-FullEnvironmentReport {
    param([string]$ProjectRoot)
    return @{
        JDK      = Check-JDK
        Maven    = Check-Maven
        NodeJS   = Check-NodeJS
        Pnpm     = Check-Pnpm
        Docker   = Check-Docker
        Port3306 = Check-Port -Port 3306
        Port6379 = Check-Port -Port 6379
        Port8085 = Check-Port -Port 8085
        Port8086 = Check-Port -Port 8086
        Port9527 = Check-Port -Port 9527
        Port5173 = Check-Port -Port 5173
        Project  = Check-ProjectStructure -ProjectRoot $ProjectRoot
    }
}

# ===== 内联模块：ConfigManager.ps1 =====
$script:ConfigPath = Join-Path $env:APPDATA "Mall4jLauncher"
$script:ConfigFile = Join-Path $script:ConfigPath "config.xml"

function Get-DefaultConfigFromYml {
    param([string]$ProjectRoot)
    $config = @{ MysqlUser = "root"; MysqlPass = ""; RedisHost = "127.0.0.1"; RedisPort = 6379; DbName = "yami_shops"; Profile = "dev" }
    $ymlPaths = @(
        (Join-Path $ProjectRoot "yami-shop-admin/src/main/resources/application-dev.yml"),
        (Join-Path $ProjectRoot "yami-shop-api/src/main/resources/application-dev.yml")
    )
    foreach ($ymlPath in $ymlPaths) {
        if (Test-Path $ymlPath) {
            try {
                $content = Get-Content $ymlPath -Raw -Encoding UTF8
                if ($content -match 'username:\s*(\S+)') { $config.MysqlUser = $matches[1] }
                if ($content -match "password:\s*'([^']*)'") { $config.MysqlPass = $matches[1] }
                elseif ($content -match 'password:\s*"([^"]*)"') { $config.MysqlPass = $matches[1] }
                elseif ($content -match 'password:\s*(\S+)') { $config.MysqlPass = $matches[1] }
                if ($content -match 'host:\s*(\S+)') { $config.RedisHost = $matches[1] }
                if ($content -match 'port:\s*(\d+)') { $config.RedisPort = [int]$matches[1] }
                break
            } catch { }
        }
    }
    return $config
}

function Save-UserConfig {
    param([hashtable]$Config)
    if (-not (Test-Path $script:ConfigPath)) { New-Item -ItemType Directory -Path $script:ConfigPath -Force | Out-Null }
    $encryptedPass = ""
    if ($Config.ContainsKey("MysqlPass") -and -not [string]::IsNullOrEmpty($Config.MysqlPass)) {
        $secureStr = ConvertTo-SecureString $Config.MysqlPass -AsPlainText -Force
        $encryptedPass = ConvertFrom-SecureString $secureStr
    }
    $xmlContent = '<?xml version="1.0" encoding="utf-8"?>
<config>
  <mysqlUser>' + $Config.MysqlUser + '</mysqlUser>
  <mysqlPassEncrypted>' + $encryptedPass + '</mysqlPassEncrypted>
  <redisHost>' + $Config.RedisHost + '</redisHost>
  <redisPort>' + $Config.RedisPort + '</redisPort>
  <profile>dev</profile>
</config>'
    try { [System.IO.File]::WriteAllText($script:ConfigFile, $xmlContent, [System.Text.Encoding]::UTF8); return $true }
    catch { return $false }
}

function Load-UserConfig {
    if (-not (Test-Path $script:ConfigFile)) { return $null }
    try {
        [xml]$xml = Get-Content $script:ConfigFile -Encoding UTF8
        $config = @{}
        if ($xml.config.mysqlUser) { $config.MysqlUser = $xml.config.mysqlUser }
        if ($xml.config.mysqlPassEncrypted -and $xml.config.mysqlPassEncrypted -ne "") {
            try {
                $secureStr = ConvertTo-SecureString $xml.config.mysqlPassEncrypted
                $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureStr)
                $config.MysqlPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            } catch { $config.MysqlPass = "" }
        } else { $config.MysqlPass = "" }
        if ($xml.config.redisHost) { $config.RedisHost = $xml.config.redisHost }
        if ($xml.config.redisPort) { $config.RedisPort = [int]$xml.config.redisPort }
        return $config
    } catch { return $null }
}

function Clear-UserConfig {
    if (Test-Path $script:ConfigFile) { Remove-Item $script:ConfigFile -Force }
}

# ===== 内联模块：ServiceManager.ps1 =====
$script:ServiceJobs = @{}

function Start-DockerDesktop {
    $dockerCheck = & docker info 2>&1
    if ("$dockerCheck" -match '(?i)(Server Version|Containers:)') { return $true }
    $knownPaths = @(
        "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
        "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
        "${env:ProgramFiles(x86)}\Docker\Docker\Docker Desktop.exe",
        "$env:LOCALAPPDATA\Docker\Docker Desktop.exe",
        "$env:ProgramW6432\Docker\Docker\Docker Desktop.exe"
    )
    $dockerExe = $null
    foreach ($p in $knownPaths) { if (Test-Path $p) { $dockerExe = $p; break } }
    if (-not $dockerExe) {
        $startMenu = [Environment]::GetFolderPath('CommonStartMenu')
        $shortcut = Get-ChildItem -Path "$startMenu\*" -Recurse -Include "Docker Desktop.lnk" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($shortcut) { $dockerExe = $shortcut.FullName }
    }
    if (-not $dockerExe -and (Get-Command docker -ErrorAction SilentlyContinue)) {
        $dockerCmd = (Get-Command docker).Source
        $dockerExe = Join-Path (Split-Path $dockerCmd -Parent) "Docker Desktop.exe"
        if (-not (Test-Path $dockerExe)) { $dockerExe = $null }
    }
    if (-not $dockerExe) { return $false }
    try { $proc = Start-Process -FilePath $dockerExe -WindowStyle Hidden -PassThru; return $true }
    catch { return $false }
}

function Wait-ForDockerDaemon {
    param([int]$TimeoutSeconds = 60)
    $startTime = Get-Date
    while ((Get-Date) -lt $startTime.AddSeconds($TimeoutSeconds)) {
        $dockerCheck = & docker info 2>&1
        if ("$dockerCheck" -match '(?i)(Server Version|Containers:)') { return $true }
        Start-Sleep -Seconds 2
    }
    return $false
}

function Test-PortListening {
    param([int]$Port)
    $lines = netstat -an 2>&1 | Select-String ":$Port\s" | Select-String "LISTEN|听|ESCUCH|ECOUTE|LAUSCHE"
    return [bool]$lines
}

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
        $result.Success = $true; $result.Message = "Redis already running (port 6379)"
        & $LogCallback "Redis already running (port 6379)"; return $result
    }
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        $result.Message = "Docker command not found. Please install Docker Desktop first."
        & $LogCallback "Docker command not found. Please install Docker Desktop first."; return $result
    }
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
                & $LogCallback "Docker Desktop did not become ready within 60s"; return $result
            }
            & $LogCallback "Docker Desktop is now ready"
        } else {
            & $LogCallback "Could not find Docker Desktop executable."
            $result.Message = "Docker Desktop not found. Please start it manually."; return $result
        }
    }
    & $LogCallback "Starting Redis (Docker)..."
    $maxRetries = 3; $attempt = 0
    while ($attempt -lt $maxRetries) {
        $attempt++; & $LogCallback "  Attempt $attempt/$maxRetries..."
        & docker rm -f yami-redis 2>&1 | Out-Null
        & docker pull redis:5.0.4 2>&1 | Out-Null
        & docker run -d --name yami-redis -p 6379:6379 redis:5.0.4 2>&1 | Out-Null
        $waitStart = Get-Date; $portReady = $false
        while ((Get-Date) -lt $waitStart.AddSeconds(20)) {
            if (Test-PortListening -Port 6379) { $portReady = $true; break }
            Start-Sleep -Milliseconds 1000
        }
        if ($portReady) {
            $result.Success = $true; $result.Message = "Redis started"
            & $LogCallback "Redis started (127.0.0.1:6379)"; return $result
        }
        if ($attempt -lt $maxRetries) {
            & $LogCallback "  Port 6379 not ready, retrying..."
            & docker rm -f yami-redis 2>&1 | Out-Null; Start-Sleep -Seconds 2
        }
    }
    $inspect = & docker inspect yami-redis --format '{{.State.Status}}' 2>&1
    & $LogCallback "Redis container status: $inspect"
    $result.Message = "Redis failed to start after $maxRetries attempts"
    & $LogCallback "Redis failed to start. Check Docker Desktop and try manually:"
    & $LogCallback "  docker run -d --name yami-redis -p 6379:6379 redis:5.0.4"
    return $result
}

function Start-BackendService {
    param([ValidateSet("admin", "api")][string]$ServiceName, [string]$ProjectRoot, [scriptblock]$LogCallback, [int]$TimeoutSeconds = 90)
    if (-not $LogCallback) { $LogCallback = { param($m) } }
    $result = @{ Success = $false; Message = ""; Process = $null }
    $port = if ($ServiceName -eq "admin") { 8085 } else { 8086 }
    $jarDir = Join-Path $ProjectRoot "yami-shop-$ServiceName/target"
    $jarFile = Join-Path $jarDir "yami-shop-$ServiceName-0.0.1-SNAPSHOT.jar"
    $portCheck = Check-Port -Port $port
    if ($portCheck.InUse) {
        if ($portCheck.ProcessName -eq "java") {
            $result.Success = $true; $result.Message = "$ServiceName already running (port $port)"
            & $LogCallback "$ServiceName already running (port $port)"; return $result
        } else {
            $result.Message = "Port $port in use by $($portCheck.ProcessName)"
            & $LogCallback "Port $port in use by $($portCheck.ProcessName)"; return $result
        }
    }
    if (-not (Test-Path $jarFile)) {
        $result.Message = "JAR not found: $jarFile"; & $LogCallback "JAR not found: $jarFile. Build first."; return $result
    }
    & $LogCallback "Starting $ServiceName backend (port $port)..."
    try {
        $jobName = "mall4j-$ServiceName"
        $jobScript = { param($JarPath, $Port) $logFile = Join-Path $env:TEMP "mall4j-$Port.log"; $p = Start-Process -FilePath "java" -ArgumentList "-jar -Dspring.profiles.active=dev -Xms512m -Xmx512m `"$JarPath`"" -NoNewWindow -PassThru -RedirectStandardOutput $logFile -RedirectStandardError $logFile; $p.WaitForExit() }
        $job = Start-Job -Name $jobName -ScriptBlock $jobScript -ArgumentList $jarFile, $port
        $script:ServiceJobs[$ServiceName] = $job
        & $LogCallback "Waiting for $ServiceName (max ${TimeoutSeconds}s)..."
        $waitOk = Wait-ForPort -Port $port -TimeoutSeconds $TimeoutSeconds
        if ($waitOk) { $result.Success = $true; $result.Message = "$ServiceName started"; & $LogCallback "$ServiceName started (port $port)" }
        else { $result.Message = "$ServiceName start timeout"; & $LogCallback "$ServiceName start timeout" }
    } catch { $result.Message = "$ServiceName error: $_"; & $LogCallback "$ServiceName error: $_" }
    return $result
}

function Start-FrontendService {
    param([ValidateSet("mall4v", "mall4uni")][string]$FrontendName, [string]$ProjectRoot, [scriptblock]$LogCallback, [int]$TimeoutSeconds = 120)
    if (-not $LogCallback) { $LogCallback = { param($m) } }
    $result = @{ Success = $false; Message = ""; Port = 0 }
    $frontendDir = Join-Path $ProjectRoot "front-end/$FrontendName"
    $port = if ($FrontendName -eq "mall4v") { 9527 } else { 5173 }
    $pkgMgr = if ($FrontendName -eq "mall4v") { "pnpm" } else { "npm" }
    $devCmd = if ($FrontendName -eq "mall4v") { "pnpm dev" } else { "npm run dev" }
    $portCheck = Check-Port -Port $port
    if ($portCheck.InUse) { $result.Success = $true; $result.Port = $port; $result.Message = "$FrontendName already running (port $port)"; & $LogCallback "$FrontendName already running (port $port)"; return $result }
    if (-not (Test-Path $frontendDir)) { $result.Message = "Directory not found: $frontendDir"; & $LogCallback "Directory not found: front-end/$FrontendName"; return $result }
    $nodeModules = Join-Path $frontendDir "node_modules"
    if (-not (Test-Path $nodeModules)) {
        & $LogCallback "Installing $FrontendName dependencies..."
        try { $installProc = Start-Process -FilePath $pkgMgr -ArgumentList "--prefix", $frontendDir, "install" -NoNewWindow -PassThru -Wait -RedirectStandardOutput "$env:TEMP\${FrontendName}_install.log" -RedirectStandardError "$env:TEMP\${FrontendName}_install_err.log"
            if ($installProc.ExitCode -ne 0) { $result.Message = "Dependency install failed"; & $LogCallback "Dependency install failed for $FrontendName"; return $result }
            & $LogCallback "Dependencies installed for $FrontendName"
        } catch { $result.Message = "Install error: $_"; & $LogCallback "Install error for ${FrontendName}: $_"; return $result }
    }
    & $LogCallback "Starting $FrontendName dev server (port $port)..."
    try {
        $jobName = "frontend-$FrontendName"; $jobScript = { param($Dir) Set-Location $Dir; $logFile = Join-Path $env:TEMP "mall4j-frontend.log"; $p = Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -Command `"& {pnpm dev}`"" -NoNewWindow -PassThru; $p.WaitForExit() }
        $job = Start-Job -Name $jobName -ScriptBlock $jobScript -ArgumentList $frontendDir; $script:ServiceJobs[$jobName] = $job
        $waitOk = Wait-ForPort -Port $port -TimeoutSeconds $TimeoutSeconds
        if ($waitOk) { $result.Success = $true; $result.Port = $port; $result.Message = "$FrontendName started"; & $LogCallback "$FrontendName started (http://localhost:$port)" }
        else { $result.Message = "$FrontendName start timeout"; & $LogCallback "$FrontendName start timeout (${TimeoutSeconds}s)" }
    } catch { $result.Message = "$FrontendName error: $_"; & $LogCallback "$FrontendName error: $_" }
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

function Install-LocalMaven {
    param([scriptblock]$LogCallback)
    if (-not $LogCallback) { $LogCallback = { param($m) } }
    $mavenRoot = Join-Path $env:APPDATA "Mall4jLauncher\maven"
    $mvnExe = Join-Path $mavenRoot "bin\mvn.cmd"
    if (Test-Path $mvnExe) {
        & $LogCallback "Local Maven found: $mvnExe"
        return $mvnExe
    }
    $version = "3.9.9"
    $zipUrl = "https://dlcdn.apache.org/maven/maven-3/$version/binaries/apache-maven-$version-bin.zip"
    $zipPath = "$env:TEMP\apache-maven-$version-bin.zip"
    & $LogCallback "Downloading Maven $version from Apache (may take a while)..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $wc = New-Object System.Net.WebClient
        & $LogCallback "  Downloading: $zipUrl"
        $wc.DownloadFile($zipUrl, $zipPath)
        $wc.Dispose()
    } catch {
        & $LogCallback "Primary mirror failed, trying backup..." -Level "WARN"
        try {
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile("https://archive.apache.org/dist/maven/maven-3/$version/binaries/apache-maven-$version-bin.zip", $zipPath)
            $wc.Dispose()
        } catch {
            & $LogCallback "Download failed: $_" -Level "ERROR"
            return $null
        }
    }
    & $LogCallback "Extracting Maven..."
    try {
        $tempExtract = "$env:TEMP\maven-extract"
        Expand-Archive -Path $zipPath -DestinationPath $tempExtract -Force
        $extracted = Join-Path $tempExtract "apache-maven-$version"
        if (-not (Test-Path $extracted)) {
            # 某些版本压缩包目录名可能不同
            $extracted = Get-ChildItem $tempExtract -Directory | Select-Object -First 1 -ExpandProperty FullName
        }
        if (-not (Test-Path $mavenRoot)) { New-Item -ItemType Directory -Path $mavenRoot -Force | Out-Null }
        Move-Item -Path "$extracted\*" -Destination $mavenRoot -Force
        Remove-Item -Path $tempExtract -Recurse -Force
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    } catch {
        & $LogCallback "Extraction failed: $_" -Level "ERROR"
        return $null
    }
    if (Test-Path $mvnExe) {
        & $LogCallback "Maven installed locally: $mvnExe" -Level "SUCCESS"
        return $mvnExe
    }
    # 可能是 mvn (无 .cmd) 的情况
    $mvnExe2 = Join-Path $mavenRoot "bin\mvn"
    if (Test-Path $mvnExe2) { return $mvnExe2 }
    & $LogCallback "Maven install failed: $mvnExe not found" -Level "ERROR"
    return $null
}

function Invoke-MavenBuild {
    param([string]$ProjectRoot, [string]$Module = "", [scriptblock]$LogCallback, [int]$TimeoutSeconds = 300)
    if (-not $LogCallback) { $LogCallback = { param($m) } }
    $result = @{ Success = $false; Message = ""; Duration = 0 }
    $mvnArgs = @("clean", "package", "-DskipTests")
    if ($Module) { $mvnArgs = @("clean", "package", "-pl", "yami-shop-$Module", "-am", "-DskipTests") }
    $moduleLabel = if ($Module) { $Module } else { "all modules" }
    & $LogCallback "Building backend ($moduleLabel)..."; & $LogCallback "  mvn $($mvnArgs -join ' ')"
    $startTime = Get-Date; $logFile = "$env:TEMP\mall4j_maven_build.log"
    try {
        $proc = Start-Process -FilePath "mvn" -ArgumentList $mvnArgs -NoNewWindow -PassThru -WorkingDirectory $ProjectRoot -RedirectStandardOutput $logFile -RedirectStandardError "${logFile}.err"
        $proc.WaitForExit($TimeoutSeconds * 1000)
        $duration = [int]((Get-Date) - $startTime).TotalSeconds; $result.Duration = $duration
        if ($proc.ExitCode -eq 0) { $result.Success = $true; $result.Message = "Build OK (${duration}s)"; & $LogCallback "Build OK (${duration}s)" }
        else { & $LogCallback "Build FAILED"; Get-Content $logFile -Tail 10 -ErrorAction SilentlyContinue | ForEach-Object { & $LogCallback "  $_" }; $result.Message = "Build failed" }
    } catch { $result.Message = "Build error: $_"; & $LogCallback "Build error: $_" }
    return $result
}

function Import-Database {
    param([string]$ProjectRoot, [string]$User = "root", [string]$Password = "", [scriptblock]$LogCallback)
    if (-not $LogCallback) { $LogCallback = { param($m) } }
    $result = @{ Success = $false; Message = "" }
    $sqlFile = Join-Path $ProjectRoot "db/yami_shop.sql"
    if (-not (Test-Path $sqlFile)) { $result.Message = "SQL file not found: $sqlFile"; & $LogCallback "SQL file not found: db/yami_shop.sql"; return $result }
    $mysqlExe = Find-MySqlClient
    if (-not $mysqlExe) { $result.Message = "mysql client not found. Import manually: db/yami_shop.sql"; & $LogCallback "mysql client not found. Import db/yami_shop.sql manually."; return $result }
    & $LogCallback "Importing database yami_shops..."
    try {
        & $mysqlExe "-u$User" "-p$Password" -e "CREATE DATABASE IF NOT EXISTS `yami_shops` DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_general_ci" 2>&1 | Out-Null
        $importProc = Start-Process -FilePath $mysqlExe -ArgumentList "-u$User", "-p$Password", "yami_shops" -NoNewWindow -PassThru -RedirectStandardInput $sqlFile -RedirectStandardOutput "$env:TEMP\mysql_import.log" -RedirectStandardError "$env:TEMP\mysql_import_err.log"
        $importProc.WaitForExit(120000)
        if ($importProc.ExitCode -eq 0) { $result.Success = $true; $result.Message = "Database imported"; & $LogCallback "Database yami_shops imported" }
        else { $errMsg = Get-Content "$env:TEMP\mysql_import_err.log" -Raw -ErrorAction SilentlyContinue; $result.Message = "Import failed: $errMsg"; & $LogCallback "Import failed: $errMsg" }
    } catch { $result.Message = "Import error: $_"; & $LogCallback "Import error: $_" }
    return $result
}

function Stop-AllServices {
    param([scriptblock]$LogCallback)
    if (-not $LogCallback) { $LogCallback = { param($m) } }
    & $LogCallback "Stopping all services..."
    @("admin", "api").ForEach({ if ($script:ServiceJobs.ContainsKey($_)) { Stop-Job -Job $script:ServiceJobs[$_] -ErrorAction SilentlyContinue; Remove-Job -Job $script:ServiceJobs[$_] -ErrorAction SilentlyContinue } })
    @("frontend-mall4v", "frontend-mall4uni").ForEach({ if ($script:ServiceJobs.ContainsKey($_)) { Stop-Job -Job $script:ServiceJobs[$_] -ErrorAction SilentlyContinue; Remove-Job -Job $script:ServiceJobs[$_] -ErrorAction SilentlyContinue } })
    $javaProcs = Get-Process -Name "java" -ErrorAction SilentlyContinue | Where-Object { try { $_.CommandLine -match "yami-shop" } catch { $false } }
    if ($javaProcs) { $javaProcs | Stop-Process -Force -ErrorAction SilentlyContinue; & $LogCallback "Stopped $($javaProcs.Count) Java process(es)" }
    & $LogCallback "All services stopped"
}

# ===== 内联模块：LogManager.ps1 =====
$script:LogFilePath = $null

function Initialize-Log {
    param([string]$LogDir)
    $logDir = if ($LogDir) { $LogDir } else { Join-Path $PSScriptRoot "logs" }
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $script:LogFilePath = Join-Path $logDir "mall4j-launcher-$timestamp.log"
    $header = "============================================" + "`r`n Mall4j Launcher Log Started at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" + "`r`n============================================"
    Add-Content -Path $script:LogFilePath -Value $header -Encoding UTF8
}

function Write-LauncherLog {
    param([string]$Message, [ValidateSet("INFO","WARN","ERROR","DEBUG","SUCCESS")][string]$Level = "INFO", [scriptblock]$UIFunc = $null)
    $timestamp = Get-Date -Format "HH:mm:ss.fff"; $logLine = "[$timestamp][$Level] $Message"
    if ($script:LogFilePath) { Add-Content -Path $script:LogFilePath -Value $logLine -Encoding UTF8 }
    if ($UIFunc) { try { & $UIFunc $Message $Level } catch {} }
    switch ($Level) {
        "ERROR"   { Write-Host $logLine -ForegroundColor Red }
        "WARN"    { Write-Host $logLine -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logLine -ForegroundColor Green }
        "DEBUG"   { Write-Host $logLine -ForegroundColor Gray }
        default   { Write-Host $logLine -ForegroundColor White }
    }
}

function Get-LogContent {
    param([int]$Lines = 100)
    if ($script:LogFilePath -and (Test-Path $script:LogFilePath)) { return Get-Content $script:LogFilePath -Tail $Lines -Encoding UTF8 -ErrorAction SilentlyContinue }
    return @()
}

# ===== 模块加载结束 =====

# Init log
Initialize-Log -LogDir (Join-Path $script:ScriptDir "logs")
Write-LauncherLog -Message "Mall4j Launcher started" -Level "INFO"

#=============================================
# 2. Load WPF Window
#=============================================
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$xamlPath = Join-Path $script:ScriptDir "mall4j-launcher.xaml"
if (-not (Test-Path $xamlPath)) {
    Write-Host "[ERROR] XAML file not found: $xamlPath" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

[xml]$xaml = Get-Content $xamlPath -Encoding UTF8
$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

#=============================================
# 3. Get UI Controls
#=============================================
function Get-UI {
    param([string]$Name)
    $ctrl = $window.FindName($Name)
    if (-not $ctrl) { Write-LauncherLog -Message "[WARN] UI control not found: $Name" -Level "WARN" }
    return $ctrl
}

$ui = @{}
$ui.titleBar    = Get-UI "titleBar"
$ui.btnMinimize = Get-UI "btnMinimize"
$ui.btnClose    = Get-UI "btnClose"
$ui.txtMysqlUser = Get-UI "txtMysqlUser"
$ui.txtMysqlPass = Get-UI "txtMysqlPass"
$ui.txtMysqlPassVisible = Get-UI "txtMysqlPassVisible"
$ui.chkShowPwd  = Get-UI "chkShowPwd"
$ui.btnTestDb   = Get-UI "btnTestDb"
$ui.stepList    = Get-UI "stepList"
$ui.txtLog      = Get-UI "txtLog"
$ui.btnClearLog = Get-UI "btnClearLog"
$ui.btnStart    = Get-UI "btnStart"
$ui.btnStop     = Get-UI "btnStop"
$ui.lblStatus   = Get-UI "lblStatus"

#=============================================
# 4. Steps Definition
#=============================================
$script:StepNames = @(
    "1. Environment Check",
    "2. Database Connection",
    "3. Start Redis",
    "4. Build Backend",
    "5. Start admin API",
    "6. Start api API",
    "7. Start mall4v Frontend",
    "8. Start mall4uni Frontend"
)

$script:Steps = @()
0..7 | ForEach-Object {
    $script:Steps += [PSCustomObject]@{
        Name          = $script:StepNames[$_]
        Status        = "pending"
        StatusText    = "Pending"
        StatusColor   = "#DDDDDD"
        StatusIcon    = "○"
        StatusTextColor = "#999999"
    }
}

function Update-StepUI {
    $ui.stepList.ItemsSource = $null
    $ui.stepList.ItemsSource = $script:Steps
}

#=============================================
# 5. UI Helpers
#=============================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-LauncherLog -Message $Message -Level $Level
    $window.Dispatcher.Invoke([Action]{
        $ui.txtLog.AppendText("[$timestamp][$Level] $Message`n")
        try { $ui.txtLog.CaretIndex = $ui.txtLog.Text.Length; $ui.txtLog.ScrollToCaret() } catch {}
    }, "Normal")
}

function Set-Status {
    param([string]$Text, [string]$Color = "#07C160")
    $window.Dispatcher.Invoke([Action]{
        $ui.lblStatus.Text = $Text
        $ui.lblStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Color)
    }, "Normal")
}

function Enable-Buttons {
    param([bool]$Start, [bool]$Stop)
    $window.Dispatcher.Invoke([Action]{
        $ui.btnStart.IsEnabled = $Start
        $ui.btnStop.IsEnabled = $Stop
    }, "Normal")
}

# Get password from whichever control is visible
function Get-Password {
    if ($ui.txtMysqlPassVisible.Visibility -eq 'Visible') {
        return $ui.txtMysqlPassVisible.Text
    }
    return $ui.txtMysqlPass.Password
}

# Set password to both controls
function Set-Password {
    param([string]$Value)
    $ui.txtMysqlPass.Password = $Value
    $ui.txtMysqlPassVisible.Text = $Value
}

#=============================================
# 6. Bind Events
#=============================================

# Window drag
$ui.titleBar.Add_MouseLeftButtonDown({ $window.DragMove() })

# Minimize
$ui.btnMinimize.Add_Click({ $window.WindowState = [System.Windows.WindowState]::Minimized })

# Close
$ui.btnClose.Add_Click({
    if (-not $ui.btnStop.IsEnabled) {
        Write-LogDirect -Message "User requested exit while services running" -Level "WARN"
        $r = [System.Windows.MessageBox]::Show("Services are running, exit anyway?", "Confirm", "YesNo", "Question")
        if ($r -eq "No") { return }
        try { Stop-AllServices -LogCallback { param($m) Write-Log -Message $m -Level "WARN" } } catch {}
    }
    $window.Close()
})

# Show/Hide password
$ui.chkShowPwd.Add_Checked({
    Set-Password (Get-Password)
    $ui.txtMysqlPass.Visibility = 'Collapsed'
    $ui.txtMysqlPassVisible.Visibility = 'Visible'
})
$ui.chkShowPwd.Add_Unchecked({
    Set-Password (Get-Password)
    $ui.txtMysqlPassVisible.Visibility = 'Collapsed'
    $ui.txtMysqlPass.Visibility = 'Visible'
})

# Clear log
$ui.btnClearLog.Add_Click({ $ui.txtLog.Clear() })

# Test DB connection
$ui.btnTestDb.Add_Click({
    $ui.btnTestDb.IsEnabled = $false
    $ui.btnTestDb.Content = "Testing..."
    # Force UI to update before blocking call
    $ui.btnTestDb.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
    try {
        $result = Test-MySqlConnection -User $ui.txtMysqlUser.Text -Password (Get-Password)
        if ($result.Success) {
            Write-Log -Message $result.Message -Level "SUCCESS"
            Set-Status -Text "DB connected" -Color "#07C160"
        Write-LogDirect -Message $result.Message -Level "SUCCESS"
        } else {
            Write-Log -Message $result.Message -Level "ERROR"
            Set-Status -Text "DB connection failed" -Color "#FA5151"
        Write-LogDirect -Message $result.Message -Level "ERROR"
        }
    } catch {
        Write-Log -Message "Test exception: $_" -Level "ERROR"
        Write-LogDirect -Message "Connection test error: $_" -Level "ERROR"
    } finally {
        $ui.btnTestDb.IsEnabled = $true
        $ui.btnTestDb.Content = "Test"
    }
})

$script:Step = -1
$script:StepUser = ""
$script:StepPass = ""
$script:StepJob = $null
$script:StepTimer = $null
$script:StepAdminResult = $null
$script:StepApiResult = $null
$script:StepMall4vResult = $null
$script:StepMall4uniResult = $null
$script:StepBuildResult = $null
$script:RedisStartTime = $null

function Start-StepTimer {
    $script:StepTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:StepTimer.Interval = [TimeSpan]::FromMilliseconds(300)
    $script:StepTimer.Add_Tick({ Process-Step })
    $script:StepTimer.Start()
}

function Stop-StepTimer {
    if ($script:StepTimer) { $script:StepTimer.Stop(); $script:StepTimer = $null }
}

function Write-LogDirect {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "HH:mm:ss"
    try {
        $ui.txtLog.AppendText("[$ts][$Level] $Message`n")
        $ui.txtLog.CaretIndex = $ui.txtLog.Text.Length
        $ui.txtLog.ScrollToCaret()
    } catch {
        Write-LauncherLog -Message $Message -Level $Level
    }
}

function Set-StepDirect {
    param([int]$Id, [string]$Status, [string]$Text)
    if ($Id -ge $script:Steps.Count) { return }
    $item = $script:Steps[$Id]
    if (-not $item) { return }
    $item.Status = $Status
    $item.StatusText = $Text
    switch ($Status) {
        "completed" { $item.StatusColor = "#07C160"; $item.StatusIcon = "V"; try { $item.StatusTextColor = "#07C160" } catch {} }
        "failed"    { $item.StatusColor = "#FA5151"; $item.StatusIcon = "X"; try { $item.StatusTextColor = "#FA5151" } catch {} }
        "running"   { $item.StatusColor = "#07C160"; $item.StatusIcon = "~"; try { $item.StatusTextColor = "#07C160" } catch {} }
        default     { $item.StatusColor = "#DDDDDD"; $item.StatusIcon = "o"; try { $item.StatusTextColor = "#999999" } catch {} }
    }
    Update-StepUI
}

function Process-Step {
    if ($script:Step -lt 0 -or $script:Step -gt 13) { return }

    # If a job is running, check completion
    if ($script:StepJob) {
        if ($script:StepJob.State -eq "Running") { return }  # Still running
        # Job completed - save result for the step
        $result = Receive-Job -Job $script:StepJob -Keep -ErrorAction SilentlyContinue
        Remove-Job -Job $script:StepJob -Force -ErrorAction SilentlyContinue
        $script:StepJob = $null
        if ($script:Step -eq 4) { $script:StepBuildResult = $result }
    }

    try {
    switch ($script:Step) {
        0 {  # Env check
            Set-StepDirect -Id 0 -Status "running" -Text "Checking..."
            Write-LogDirect -Message "Checking environment..." -Level "INFO"
            $env = Get-FullEnvironmentReport -ProjectRoot $script:ProjectRoot
            Write-LogDirect -Message "  JDK: $(if($env.JDK.Ok){'OK'}else{'FAIL'}) v$($env.JDK.Version)" -Level "INFO"
            Write-LogDirect -Message "  Maven: $(if($env.Maven.Ok){'OK'}else{'FAIL'}) $($env.Maven.Version)" -Level "INFO"
            Write-LogDirect -Message "  Node: $(if($env.NodeJS.Ok){'OK'}else{'FAIL'}) $($env.NodeJS.Version)" -Level "INFO"
            Write-LogDirect -Message "  Docker: $(if($env.Docker.Ok){'OK'}else{'FAIL'})" -Level "INFO"
            Write-LogDirect -Message "  Project: $(if($env.Project.Ok){'OK'}else{'FAIL'})" -Level "INFO"
            Set-StepDirect -Id 0 -Status "completed" -Text "Done"
            $script:Step = 1
        }
        1 {  # DB connection
            Set-StepDirect -Id 1 -Status "running" -Text "Connecting..."
            Write-LogDirect -Message "Testing MySQL connection..." -Level "INFO"
            $dbResult = Test-MySqlConnection -User $script:StepUser -Password $script:StepPass
            if ($dbResult.Success) {
                Write-LogDirect -Message "$($dbResult.Message)" -Level "SUCCESS"
                Set-StepDirect -Id 1 -Status "completed" -Text "Connected"
                if (-not $dbResult.DatabaseExists) {
                    Write-LogDirect -Message "Importing database..." -Level "WARN"
                    $importResult = Import-Database -ProjectRoot $script:ProjectRoot -User $script:StepUser -Password $script:StepPass -LogCallback { param($m) Write-LogDirect -Message $m -Level "INFO" }
                    if ($importResult.Success) {
                        Write-LogDirect -Message "Database imported" -Level "SUCCESS"
                    } else {
                        Write-LogDirect -Message "Import failed, import manually: db/yami_shop.sql" -Level "ERROR"
                        Set-StepDirect -Id 1 -Status "failed" -Text "Import failed"
                        Set-Status -Text "DB import failed" -Color "#FA5151"
                        Enable-Buttons -Start $true -Stop $false; Stop-StepTimer; $script:Step = -1; return
                    }
                }
                $script:Step = 2
            } else {
                Write-LogDirect -Message "$($dbResult.Message)" -Level "ERROR"
                Write-LogDirect -Message "Update MySQL credentials and retry" -Level "INFO"
                Set-StepDirect -Id 1 -Status "failed" -Text "Connection failed"
                Set-Status -Text "MySQL connection failed" -Color "#FA5151"
                Enable-Buttons -Start $true -Stop $false; Stop-StepTimer; $script:Step = -1
            }
        }
        2 {  # Redis
            if (-not $script:RedisStartTime) {
                # 第一次进入 Step 2：检查或启动 Redis
                Set-StepDirect -Id 2 -Status "running" -Text "Starting..."
                $portCheck = Check-Port -Port 6379
                if ($portCheck.InUse) {
                    Write-LogDirect -Message "Redis already running (port 6379)" -Level "SUCCESS"
                    Set-StepDirect -Id 2 -Status "completed" -Text "Already running"
                    $script:Step = 3
                } else {
                    Write-LogDirect -Message "Starting Redis..." -Level "INFO"
                    # 检查 docker 命令
                    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
                        Write-LogDirect -Message "Docker command not found. Please install Docker Desktop." -Level "ERROR"
                        Set-StepDirect -Id 2 -Status "failed" -Text "Docker not found"
                        Set-Status -Text "Redis failed: Docker not installed" -Color "#FA5151"
                        Enable-Buttons -Start $true -Stop $false; Stop-StepTimer; $script:Step = -1; return
                    }
                    # 检查 Docker Desktop 是否运行
                    $dockerCheck = & docker info 2>&1
                    if ("$dockerCheck" -notmatch '(?i)(Server Version|Containers:)') {
                        Write-LogDirect -Message "Docker Desktop not running, attempting to start..." -Level "INFO"
                        $ddStarted = Start-DockerDesktop
                        if ($ddStarted) {
                            Write-LogDirect -Message "Docker Desktop launch initiated..." -Level "INFO"
                        } else {
                            Write-LogDirect -Message "Could not find Docker Desktop. Please start it manually." -Level "WARN"
                        }
                    } else {
                        Write-LogDirect -Message "Docker Desktop is running" -Level "INFO"
                    }
                    # 清理旧容器
                    & docker rm -f yami-redis 2>&1 | Out-Null
                    # 启动容器（docker run -d 异步返回，不等就绪）
                    & docker run -d --name yami-redis -p 6379:6379 redis:5.0.4 2>&1 | Out-Null
                    # 记录开始时间，进入轮询
                    $script:RedisStartTime = Get-Date
                    Write-LogDirect -Message "Redis container launched, polling port 6379..." -Level "INFO"
                }
            } else {
                # 轮询模式：检查端口是否就绪
                $check = Test-PortListening -Port 6379
                $elapsed = [int]((Get-Date) - $script:RedisStartTime).TotalSeconds
                if ($check) {
                    Write-LogDirect -Message "Redis started (port 6379, ${elapsed}s)" -Level "SUCCESS"
                    Set-StepDirect -Id 2 -Status "completed" -Text "Started (${elapsed}s)"
                    $script:RedisStartTime = $null; $script:Step = 3
                } elseif ($elapsed -ge 90) {
                    Write-LogDirect -Message "Redis did not start within 90s, giving up" -Level "ERROR"
                    # 检查容器状态
                    $status = & docker inspect yami-redis --format '{{.State.Status}}' 2>&1
                    Write-LogDirect -Message "  Container status: $status" -Level "INFO"
                    Set-StepDirect -Id 2 -Status "failed" -Text "Timeout"
                    Set-Status -Text "Redis start timeout" -Color "#FA5151"
                    $script:RedisStartTime = $null
                    Enable-Buttons -Start $true -Stop $false; Stop-StepTimer; $script:Step = -1
                }
                # 未超时且未就绪：继续等待（不输出日志避免刷屏，每 10 秒提示一次）
                elseif ($elapsed % 10 -eq 0) {
                    Write-LogDirect -Message "  Waiting for Redis... (${elapsed}s)" -Level "INFO"
                }
            }
        }
        3 {  # Build backend - start the build
            # 先检查预编译 JAR 是否存在
            $jarsExist = Test-JarsExist -ProjectRoot $script:ProjectRoot
            if ($jarsExist.AllExist) {
                Write-LogDirect -Message "Pre-built JARs found, skipping Maven build" -Level "SUCCESS"
                Set-StepDirect -Id 3 -Status "completed" -Text "Skipped (JARs exist)"
                $script:Step = 5
                return
            }
            # JAR 不存在，自动下载 Maven
            Write-LogDirect -Message "Maven not found, downloading locally..." -Level "INFO"
            Set-StepDirect -Id 3 -Status "running" -Text "Downloading Maven..."
            Set-Status -Text "Downloading Maven (~1 min)..." -Color "#FFC300"
            $mvnPath = Install-LocalMaven -LogCallback { param($m) Write-LogDirect -Message $m -Level "INFO" }
            if (-not $mvnPath) {
                Write-LogDirect -Message "Failed to download Maven. Check internet connection." -Level "ERROR"
                Write-LogDirect -Message "Alternatively, copy pre-built JARs to target/ directories." -Level "INFO"
                Set-StepDirect -Id 3 -Status "failed" -Text "Download failed"
                Set-Status -Text "Maven download failed" -Color "#FA5151"
                Enable-Buttons -Start $true -Stop $false
                Stop-StepTimer
                $script:Step = -1
                return
            }
            Write-LogDirect -Message "Maven ready: $mvnPath" -Level "SUCCESS"
            Set-StepDirect -Id 3 -Status "running" -Text "Building..."
            Set-Status -Text "Building backend (~1-3 min)..." -Color "#FFC300"
            Write-LogDirect -Message "Building backend..." -Level "INFO"
            $script:StepBuildResult = $null
            $script:StepJob = Start-Job -Name "step-build" -ScriptBlock {
                param($root, $mvn)
                $logFile = "$env:TEMP\mall4j_build.log"
                $p = Start-Process -FilePath $mvn -ArgumentList "clean package -DskipTests" -NoNewWindow -PassThru -WorkingDirectory $root -RedirectStandardOutput $logFile -RedirectStandardError "${logFile}.err"
                if (-not $p) { return "FAILED" }
                $p.WaitForExit(300000)
                if ($p.ExitCode -eq 0) { return "OK" } else { return "FAILED" }
            } -ArgumentList $script:ProjectRoot, $mvnPath
            $script:Step = 4
            Write-LogDirect -Message "Maven build started, waiting for completion..." -Level "INFO"
        }
        4 {  # Check build result (job completed, result stored at top of Process-Step)
            if ($script:StepJob) { return }  # Still running, wait
            # At this point $script:StepBuildResult should have been set
            if ($script:StepBuildResult -eq "OK") {
                Write-LogDirect -Message "Build OK" -Level "SUCCESS"
                Set-StepDirect -Id 3 -Status "completed" -Text "Build OK"
                $script:Step = 5
            } else {
                Set-Status -Text "Build failed" -Color "#FA5151"
                Set-StepDirect -Id 3 -Status "failed" -Text "Build failed"
                Enable-Buttons -Start $true -Stop $false
                Stop-StepTimer
                $script:Step = -1
            }
        }
        5 {  # Start admin
            Set-StepDirect -Id 4 -Status "running" -Text "Starting..."
            Set-Status -Text "Starting admin backend..." -Color "#07C160"
            Write-LogDirect -Message "Starting admin (port 8085)..." -Level "INFO"
            $jarFile = Join-Path $script:ProjectRoot "yami-shop-admin/target/yami-shop-admin-0.0.1-SNAPSHOT.jar"
            if (-not (Test-Path $jarFile)) {
                Write-LogDirect -Message "JAR not found: $jarFile" -Level "ERROR"
                Set-StepDirect -Id 4 -Status "failed" -Text "JAR not found"
                Enable-Buttons -Start $true -Stop $false; Stop-StepTimer; $script:Step = -1; return
            }
            $logFile = "$env:TEMP\mall4j-admin.log"
            $javaArgs = @("-jar", "-Dspring.profiles.active=dev", "-Dspring.datasource.username=$($script:StepUser)", "-Dspring.datasource.password=$($script:StepPass)", "-Xms512m", "-Xmx512m", "`"$jarFile`"")
            $p = Start-Process -FilePath "java" -WindowStyle Hidden -ArgumentList $javaArgs -PassThru -RedirectStandardOutput $logFile -RedirectStandardError "${logFile}.err"
            if (-not $p) {
                Write-LogDirect -Message "Failed to start admin process" -Level "ERROR"
                Set-StepDirect -Id 4 -Status "failed" -Text "Launch failed"
                Enable-Buttons -Start $true -Stop $false; Stop-StepTimer; $script:Step = -1; return
            }
            Write-LogDirect -Message "Admin process started (PID $($p.Id)), waiting for port 8085..." -Level "INFO"
            $script:AdminPid = $p.Id
            $script:Step = 6
        }
        6 {  # Wait for admin port
            $port = Check-Port -Port 8085
            if ($port.InUse) {
                Write-LogDirect -Message "Admin started (port 8085)" -Level "SUCCESS"
                Set-StepDirect -Id 4 -Status "completed" -Text "Started"
                $script:Step = 7
            }
            # Continue waiting (timer will retry)
        }
        7 {  # Start api
            Set-StepDirect -Id 5 -Status "running" -Text "Starting..."
            Set-Status -Text "Starting api backend..." -Color "#07C160"
            Write-LogDirect -Message "Starting api (port 8086)..." -Level "INFO"
            $jarFile = Join-Path $script:ProjectRoot "yami-shop-api/target/yami-shop-api-0.0.1-SNAPSHOT.jar"
            if (-not (Test-Path $jarFile)) {
                Write-LogDirect -Message "JAR not found: $jarFile" -Level "ERROR"
                Set-StepDirect -Id 5 -Status "failed" -Text "JAR not found"
                Enable-Buttons -Start $true -Stop $false; Stop-StepTimer; $script:Step = -1; return
            }
            $logFile = "$env:TEMP\mall4j-api.log"
            $javaArgs = @("-jar", "-Dspring.profiles.active=dev", "-Dspring.datasource.username=$($script:StepUser)", "-Dspring.datasource.password=$($script:StepPass)", "-Xms512m", "-Xmx512m", "`"$jarFile`"")
            $p = Start-Process -FilePath "java" -WindowStyle Hidden -ArgumentList $javaArgs -PassThru -RedirectStandardOutput $logFile -RedirectStandardError "${logFile}.err"
            if (-not $p) {
                Write-LogDirect -Message "Failed to start api process" -Level "ERROR"
                Set-StepDirect -Id 5 -Status "failed" -Text "Launch failed"
                Enable-Buttons -Start $true -Stop $false; Stop-StepTimer; $script:Step = -1; return
            }
            Write-LogDirect -Message "Api process started (PID $($p.Id)), waiting for port 8086..." -Level "INFO"
            $script:ApiPid = $p.Id
            $script:Step = 8
        }
        8 {  # Wait for api port
            $port = Check-Port -Port 8086
            if ($port.InUse) {
                Write-LogDirect -Message "Api started (port 8086)" -Level "SUCCESS"
                Set-StepDirect -Id 5 -Status "completed" -Text "Started"
                $script:Step = 9
            }
        }
        9 {  # Start mall4v frontend
            Set-StepDirect -Id 6 -Status "running" -Text "Starting..."
            Set-Status -Text "Starting mall4v frontend..." -Color "#07C160"
            Write-LogDirect -Message "Starting mall4v (port 9527)..." -Level "INFO"
            $dir = Join-Path $script:ProjectRoot "front-end/mall4v"
            if (-not (Test-Path (Join-Path $dir "node_modules"))) {
                Write-LogDirect -Message "Installing mall4v dependencies..." -Level "INFO"
                $install = Start-Process -FilePath "cmd.exe" -ArgumentList "/c pnpm install" -WorkingDirectory $dir -NoNewWindow -PassThru -Wait
                if ($install.ExitCode -ne 0) {
                    Write-LogDirect -Message "pnpm install failed" -Level "ERROR"
                    Set-StepDirect -Id 6 -Status "failed" -Text "Install failed"; $script:Step = -1; return
                }
            }
            $p = Start-Process -FilePath "cmd.exe" -ArgumentList "/c pnpm dev" -WorkingDirectory $dir -NoNewWindow -PassThru
            if (-not $p) {
                Write-LogDirect -Message "Failed to start mall4v" -Level "ERROR"
                Set-StepDirect -Id 6 -Status "failed" -Text "Launch failed"; $script:Step = -1; return
            }
            Write-LogDirect -Message "mall4v started (PID $($p.Id)), waiting for port 9527..." -Level "INFO"
            $script:Step = 10
        }
        10 {  # Wait for mall4v port
            $port = Check-Port -Port 9527
            if ($port.InUse) {
                Write-LogDirect -Message "mall4v started (http://localhost:9527)" -Level "SUCCESS"
                Set-StepDirect -Id 6 -Status "completed" -Text "Started"
                $script:Step = 11
            }
        }
        11 {  # Start mall4uni frontend
            Set-StepDirect -Id 7 -Status "running" -Text "Starting..."
            Set-Status -Text "Starting mall4uni frontend..." -Color "#07C160"
            Write-LogDirect -Message "Starting mall4uni (port 5173)..." -Level "INFO"
            $dir = Join-Path $script:ProjectRoot "front-end/mall4uni"
            if (-not (Test-Path (Join-Path $dir "node_modules"))) {
                Write-LogDirect -Message "Installing mall4uni dependencies..." -Level "INFO"
                $install = Start-Process -FilePath "cmd.exe" -ArgumentList "/c npm install" -WorkingDirectory $dir -NoNewWindow -PassThru -Wait
                if ($install.ExitCode -ne 0) {
                    Write-LogDirect -Message "npm install failed" -Level "ERROR"
                    Set-StepDirect -Id 7 -Status "failed" -Text "Install failed"; $script:Step = -1; return
                }
            }
            $p = Start-Process -FilePath "cmd.exe" -ArgumentList "/c npm run dev" -WorkingDirectory $dir -NoNewWindow -PassThru
            if (-not $p) {
                Write-LogDirect -Message "Failed to start mall4uni" -Level "ERROR"
                Set-StepDirect -Id 7 -Status "failed" -Text "Launch failed"; $script:Step = -1; return
            }
            Write-LogDirect -Message "mall4uni started (PID $($p.Id)), waiting for port 5173..." -Level "INFO"
            $script:Step = 12
        }
        12 {  # Wait for mall4uni port
            $port = Check-Port -Port 5173
            if ($port.InUse) {
                Write-LogDirect -Message "mall4uni started (http://localhost:5173)" -Level "SUCCESS"
                Set-StepDirect -Id 7 -Status "completed" -Text "Started"
                $script:StepMall4uniResult = @{Success=$true}
                $script:Step = 13
            }
        }
        13 {  # Done
            Write-LogDirect -Message "" -Level "INFO"
            Write-LogDirect -Message "==========================================" -Level "SUCCESS"
            $now = Get-Date -Format "MM-dd HH:mm:ss"
            Write-LogDirect -Message "  [$now] Mall4j started!" -Level "SUCCESS"
            Write-LogDirect -Message "  Admin: http://localhost:9527 (admin/123456)" -Level "SUCCESS"
            Write-LogDirect -Message "  Shop:  http://localhost:5173" -Level "SUCCESS"
            Write-LogDirect -Message "==========================================" -Level "SUCCESS"
            Set-Status -Text "All services started!" -Color "#07C160"
            Enable-Buttons -Start $true -Stop $false; Stop-StepTimer; $script:Step = -1
            Show-TransparentPopup
        }
    }
    } catch { Write-LauncherLog -Message "Step error: $_" -Level "ERROR" }
}

function Show-TransparentPopup {
    $now = Get-Date -Format "MM-dd HH:mm:ss"
    $popup = New-Object Windows.Window
    $popup.WindowStyle = [Windows.WindowStyle]::None
    $popup.AllowsTransparency = $true
    $popup.Background = [System.Windows.Media.Brush]::new()
    $popup.Width = 420
    $popup.Height = 260
    $popup.WindowStartupLocation = [Windows.WindowStartupLocation]::CenterScreen
    $popup.Topmost = $true
    $popup.ShowInTaskbar = $false
    $popup.Owner = $window

    # Semi-transparent dark overlay + centered card
    $grid = New-Object Windows.Controls.Grid
    $grid.Background = [System.Windows.Media.SolidColorBrush]::new([Windows.Media.Color]::FromArgb(180, 0, 0, 0))

    # Card
    $border = New-Object Windows.Controls.Border
    $border.Width = 380
    $border.Height = 200
    $border.CornerRadius = [Windows.CornerRadius]::new(16)
    $border.Background = [System.Windows.Media.SolidColorBrush]::new([Windows.Media.Color]::FromArgb(230, 255, 255, 255))
    $border.BorderBrush = [System.Windows.Media.SolidColorBrush]::new([Windows.Media.Color]::FromArgb(60, 255, 255, 255))
    $border.BorderThickness = [Windows.Thickness]::new(1)

    $stack = New-Object Windows.Controls.StackPanel
    $stack.Margin = [Windows.Thickness]::new(24, 20, 24, 20)

    # Title
    $title = New-Object Windows.Controls.TextBlock
    $title.Text = "Mall4j Launcher"
    $title.FontSize = 20
    $title.FontWeight = [Windows.FontWeights]::Bold
    $title.Foreground = [System.Windows.Media.SolidColorBrush]::new([Windows.Media.Color]::FromArgb(255, 7, 193, 96))
    $title.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
    $title.Margin = [Windows.Thickness]::new(0, 0, 0, 8)

    # Time
    $timeBlock = New-Object Windows.Controls.TextBlock
    $timeBlock.Text = "Started at: $now"
    $timeBlock.FontSize = 12
    $timeBlock.Foreground = [System.Windows.Media.SolidColorBrush]::new([Windows.Media.Color]::FromArgb(200, 100, 100, 100))
    $timeBlock.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
    $timeBlock.Margin = [Windows.Thickness]::new(0, 0, 0, 16)

    # Separator
    $sep = New-Object Windows.Controls.Separator
    $sep.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    $sep.Foreground = [System.Windows.Media.SolidColorBrush]::new([Windows.Media.Color]::FromArgb(40, 0, 0, 0))

    # Admin
    $admin = New-Object Windows.Controls.TextBlock
    $admin.Text = "Admin: http://localhost:9527"
    $admin.FontSize = 14
    $admin.Foreground = [System.Windows.Media.SolidColorBrush]::new([Windows.Media.Color]::FromArgb(255, 50, 50, 50))
    $admin.Margin = [Windows.Thickness]::new(0, 0, 0, 4)

    # Shop
    $shop = New-Object Windows.Controls.TextBlock
    $shop.Text = "Shop:  http://localhost:5173"
    $shop.FontSize = 14
    $shop.Foreground = [System.Windows.Media.SolidColorBrush]::new([Windows.Media.Color]::FromArgb(255, 50, 50, 50))
    $shop.Margin = [Windows.Thickness]::new(0, 0, 0, 16)

    # Close hint
    $hint = New-Object Windows.Controls.TextBlock
    $hint.Text = "Click anywhere or press Esc to close"
    $hint.FontSize = 11
    $hint.Foreground = [System.Windows.Media.SolidColorBrush]::new([Windows.Media.Color]::FromArgb(150, 150, 150, 150))
    $hint.HorizontalAlignment = [Windows.HorizontalAlignment]::Center

    $stack.Children.Add($title)
    $stack.Children.Add($timeBlock)
    $stack.Children.Add($sep)
    $stack.Children.Add($admin)
    $stack.Children.Add($shop)
    $stack.Children.Add($hint)
    $border.Child = $stack

    # Center card in grid
    $border.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
    $border.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $grid.Children.Add($border)

    $popup.Content = $grid

    # Click to close
    $popup.Add_MouseLeftButtonDown({ $popup.Close() })
    $popup.Add_KeyDown({
        if ($_.Key -eq [Windows.Input.Key]::Escape) { $popup.Close() }
    })

    # Show modal
    $popup.ShowDialog() | Out-Null
}

# Start button
$ui.btnStart.Add_Click({
    $script:StepUser = $ui.txtMysqlUser.Text
    $script:StepPass = Get-Password

    # Save config
    Save-UserConfig -Config @{
        MysqlUser = $script:StepUser
        MysqlPass = $script:StepPass
        RedisHost = "127.0.0.1"; RedisPort = 6379
    } | Out-Null

    # Reset steps
    foreach ($step in $script:Steps) {
        $step.Status = "pending"; $step.StatusText = "Pending"
        $step.StatusColor = "#DDDDDD"; $step.StatusIcon = "o"
        try { $step.StatusTextColor = "#999999" } catch {}
    }
    Update-StepUI
    $ui.txtLog.Clear()
    Enable-Buttons -Start $false -Stop $true
    Set-Status -Text "Starting..." -Color "#07C160"
    Write-LogDirect -Message "Starting Mall4j..." -Level "INFO"

    $script:Step = 0
    Start-StepTimer
})

# Stop button
$ui.btnStop.Add_Click({
    Stop-StepTimer
    $script:Step = -1
    Enable-Buttons -Start $false -Stop $false
    Set-Status -Text "Stopping..." -Color "#FA5151"
    Write-LogDirect -Message "Stopping all services..." -Level "WARN"
    Stop-AllServices -LogCallback { param($m) Write-LogDirect -Message $m -Level "WARN" }
    foreach ($step in $script:Steps) {
        $step.Status = "pending"; $step.StatusText = "Pending"
        $step.StatusColor = "#DDDDDD"; $step.StatusIcon = "o"
        try { $step.StatusTextColor = "#999999" } catch {}
    }
    Update-StepUI
    Enable-Buttons -Start $true -Stop $false
    Set-Status -Text "Stopped" -Color "#999999"
    Write-LogDirect -Message "All services stopped" -Level "SUCCESS"
})

#=============================================
# 7. Window Close
#=============================================
$window.Add_Closed({
    if ($script:CurrentPS) { try { $script:CurrentPS.Dispose() } catch {} }
    if ($script:CurrentRunspace) { try { $script:CurrentRunspace.Dispose() } catch {} }
    if ($script:CurrentTimer) { try { $script:CurrentTimer.Stop() } catch {} }
})

#=============================================
# 8. Init UI
#=============================================

# Load default config from yml
$defaultConfig = Get-DefaultConfigFromYml -ProjectRoot $script:ProjectRoot
$ui.txtMysqlUser.Text = $defaultConfig.MysqlUser

# Load saved config
$savedConfig = Load-UserConfig
if ($savedConfig -and $savedConfig.MysqlPass) {
    $script:SavedPassword = $savedConfig.MysqlPass
    $window.Dispatcher.Invoke([Action]{
        $ui.txtMysqlPass.Password = $script:SavedPassword
        $ui.txtMysqlPassVisible.Text = $script:SavedPassword
    }, "Normal")
    Write-Log -Message "Loaded saved config" -Level "INFO"
}

# Initial env check
try {
    $envReport = Get-FullEnvironmentReport -ProjectRoot $script:ProjectRoot
    $script:EnvReport = $envReport

    $summaryParts = @()
    if ($envReport.JDK.Ok)      { $summaryParts += "[OK]JDK$($envReport.JDK.Version)" } else { $summaryParts += "[X]JDK" }
    if ($envReport.Maven.Ok)    { $summaryParts += "[OK]Mvn$($envReport.Maven.Version)" } else { $summaryParts += "[X]Mvn" }
    if ($envReport.NodeJS.Ok)   { $summaryParts += "[OK]Node$($envReport.NodeJS.Version)" } else { $summaryParts += "[X]Node" }
    if ($envReport.Docker.Ok)   { $summaryParts += "[OK]Docker" } else { $summaryParts += "[X]Docker" }
    if ($envReport.Project.Ok)  { $summaryParts += "[OK]Project" } else { $summaryParts += "[X]Project" }

    Set-Status -Text ($summaryParts -join " ") -Color "#333333"
    Write-Log -Message "Environment check done" -Level "INFO"
} catch {
    Write-Log -Message "Environment check failed: $_" -Level "WARN"
}

# Init step panel
Update-StepUI

#=============================================
# 9. Show Window
#=============================================
$window.Title = "Mall4j Launcher"
$window.ShowDialog() | Out-Null
