# ConfigManager.ps1 - Configuration management module

$script:ConfigPath = Join-Path $env:APPDATA "Mall4jLauncher"
$script:ConfigFile = Join-Path $script:ConfigPath "config.xml"

function Get-DefaultConfigFromYml {
    param([string]$ProjectRoot)

    $config = @{
        MysqlUser = "root"
        MysqlPass = ""
        RedisHost = "127.0.0.1"
        RedisPort = 6379
        DbName    = "yami_shops"
        Profile   = "dev"
    }

    $ymlPaths = @(
        (Join-Path $ProjectRoot "yami-shop-admin/src/main/resources/application-dev.yml"),
        (Join-Path $ProjectRoot "yami-shop-api/src/main/resources/application-dev.yml")
    )

    foreach ($ymlPath in $ymlPaths) {
        if (Test-Path $ymlPath) {
            try {
                $content = Get-Content $ymlPath -Raw -Encoding UTF8
                if ($content -match 'username:\s*(\S+)') {
                    $config.MysqlUser = $matches[1]
                }
                if ($content -match "password:\s*'([^']*)'") {
                    $config.MysqlPass = $matches[1]
                } elseif ($content -match 'password:\s*"([^"]*)"') {
                    $config.MysqlPass = $matches[1]
                } elseif ($content -match 'password:\s*(\S+)') {
                    $config.MysqlPass = $matches[1]
                }
                if ($content -match 'host:\s*(\S+)') {
                    $config.RedisHost = $matches[1]
                }
                if ($content -match 'port:\s*(\d+)') {
                    $config.RedisPort = [int]$matches[1]
                }
                break
            } catch { }
        }
    }
    return $config
}

function Save-UserConfig {
    param([hashtable]$Config)

    if (-not (Test-Path $script:ConfigPath)) {
        New-Item -ItemType Directory -Path $script:ConfigPath -Force | Out-Null
    }

    $encryptedPass = ""
    if ($Config.ContainsKey("MysqlPass") -and -not [string]::IsNullOrEmpty($Config.MysqlPass)) {
        $secureStr = ConvertTo-SecureString $Config.MysqlPass -AsPlainText -Force
        $encryptedPass = ConvertFrom-SecureString $secureStr
    }

    $xmlContent = @"
<?xml version="1.0" encoding="utf-8"?>
<config>
  <mysqlUser>$($Config.MysqlUser)</mysqlUser>
  <mysqlPassEncrypted>$encryptedPass</mysqlPassEncrypted>
  <redisHost>$($Config.RedisHost)</redisHost>
  <redisPort>$($Config.RedisPort)</redisPort>
  <profile>dev</profile>
</config>
"@

    try {
        [System.IO.File]::WriteAllText($script:ConfigFile, $xmlContent, [System.Text.Encoding]::UTF8)
        return $true
    } catch {
        return $false
    }
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

