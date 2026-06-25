# LogManager.ps1 - Log management module

$script:LogFilePath = $null

function Initialize-Log {
    param([string]$LogDir)

    $logDir = if ($LogDir) { $LogDir } else { Join-Path $PSScriptRoot "logs" }
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $script:LogFilePath = Join-Path $logDir "mall4j-launcher-$timestamp.log"

    $header = @"
============================================
 Mall4j Launcher Log
 Started at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
============================================
"@
    Add-Content -Path $script:LogFilePath -Value $header -Encoding UTF8
}

function Write-LauncherLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG", "SUCCESS")]
        [string]$Level = "INFO",
        [scriptblock]$UIFunc = $null
    )

    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    $logLine = "[$timestamp][$Level] $Message"

    if ($script:LogFilePath) {
        Add-Content -Path $script:LogFilePath -Value $logLine -Encoding UTF8
    }
    if ($UIFunc) {
        try { & $UIFunc $Message $Level } catch {}
    }

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
    if ($script:LogFilePath -and (Test-Path $script:LogFilePath)) {
        return Get-Content $script:LogFilePath -Tail $Lines -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    return @()
}

