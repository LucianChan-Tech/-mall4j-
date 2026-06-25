<#
.SYNOPSIS
    Mall4j Launcher - Rebuild EXE
.DESCRIPTION
    Uses ps2exe to compile mall4j-launcher.ps1 into "E-mall Launcher.exe".
    XAML file (mall4j-launcher.xaml) must be alongside the EXE.
    Prerequisites: PowerShell 5+, module ps2exe (Install-Module ps2exe -Force)
.USAGE
    cd launcher
    .\build-exe.ps1
#>

$ScriptDir = Split-Path $PSCommandPath -Parent
Push-Location $ScriptDir

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Mall4j Launcher - Rebuild EXE" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Step 1: Check ps2exe
Write-Host "[1/3] Checking ps2exe..." -ForegroundColor Yellow
$ps2exe = Get-Command ps2exe -ErrorAction SilentlyContinue
if (-not $ps2exe) {
    Write-Host "  ps2exe not found, installing..." -ForegroundColor Yellow
    try {
        Install-Module -Name ps2exe -Force -Scope CurrentUser -ErrorAction Stop
        Write-Host "  OK: ps2exe installed" -ForegroundColor Green
        Import-Module ps2exe -Force
    } catch {
        Write-Host "  FAIL: install error: $_" -ForegroundColor Red
        Write-Host "  Run manually: Install-Module ps2exe -Force" -ForegroundColor Gray
        Pop-Location
        exit 1
    }
} else {
    Import-Module ps2exe -Force
    Write-Host ("  OK: ps2exe " + (Get-Module ps2exe).Version) -ForegroundColor Green
}

# Step 2: Check source files
Write-Host "`n[2/3] Checking source files..." -ForegroundColor Yellow
$allOk = $true
$files = @("mall4j-launcher.ps1", "mall4j-launcher.xaml", "modules\ServiceManager.ps1", "launch-core.ps1")
$iconFile = "E-mall Launcher.ico"
$hasIcon = Test-Path $iconFile
foreach ($f in $files) {
    if (Test-Path $f) {
        Write-Host ("  [OK] " + $f) -ForegroundColor Green
    } else {
        Write-Host ("  [XX] " + $f) -ForegroundColor Red
        $allOk = $false
    }
}
if ($hasIcon) {
    Write-Host ("  [OK] " + $iconFile + " (icon)") -ForegroundColor Green
} else {
    Write-Host ("  [..] no icon file (optional)") -ForegroundColor Gray
}
if (-not $allOk) {
    Write-Host "  Missing files, aborting" -ForegroundColor Red
    Pop-Location
    exit 1
}

# Step 3: Compile
Write-Host "`n[3/3] Compiling EXE..." -ForegroundColor Yellow
$outputExe = "E-mall Launcher.exe"

# Backup old EXE
if (Test-Path $outputExe) {
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $backup = "Mall4jLauncher_backup_$ts.exe"
    Copy-Item $outputExe $backup -Force
    Write-Host ("  Backed up old EXE -> " + $backup) -ForegroundColor Gray
}

try {
    $compileArgs = @{
        InputFile = "mall4j-launcher.ps1"
        OutputFile = $outputExe
        noOutput = $true
        ErrorAction = "Stop"
    }
    if ($hasIcon) { $compileArgs.iconFile = $iconFile }
    Invoke-ps2exe @compileArgs
    if (Test-Path $outputExe) {
        $size = (Get-Item $outputExe).Length
        $sizeKB = [math]::Round($size / 1024, 1)
        Write-Host "  OK: Compilation successful!" -ForegroundColor Green
        Write-Host ("  -> $outputExe (" + $sizeKB + " KB)") -ForegroundColor Green
    } else {
        Write-Host "  FAIL: No output file generated" -ForegroundColor Red
        Pop-Location
        exit 1
    }
} catch {
    Write-Host ("  FAIL: " + $_.Exception.Message) -ForegroundColor Red
    Write-Host "`nTry manual compile:" -ForegroundColor Yellow
    Write-Host "  cd $ScriptDir" -ForegroundColor Gray
    Write-Host '  Invoke-ps2exe -InputFile "mall4j-launcher.ps1" -OutputFile "E-mall Launcher.exe" -IconFile "E-mall Launcher.ico" -noOutput' -ForegroundColor Gray
    Pop-Location
    exit 1
}

Write-Host ""
Write-Host "IMPORTANT: XAML file (mall4j-launcher.xaml) must be in the same directory as EXE" -ForegroundColor Yellow
Write-Host "When moving the EXE, also copy the XAML file alongside it." -ForegroundColor Yellow
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Compilation done!" -ForegroundColor Cyan
Write-Host "  Double-click E-mall Launcher.exe to run" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Pop-Location
