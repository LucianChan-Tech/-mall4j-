# EnvCheck.ps1 - Environment detection module

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
        if ($output -match 'Server Version') {
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
        $conn = netstat -ano | Select-String "LISTENING" | Select-String ":$Port "
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

    return @{
        Ok = $allOk
        Message = if ($allOk) { "Project structure OK" } else { "Project structure incomplete" }
        Checks = $checks
    }
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

