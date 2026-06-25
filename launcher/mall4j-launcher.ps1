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
$script:ModulesDir = Join-Path $script:ScriptDir "modules"

# Validate project root
if (-not (Test-Path (Join-Path $script:ProjectRoot "pom.xml"))) {
    Write-Host "[ERROR] Project root not found (pom.xml)" -ForegroundColor Red
    Write-Host "Place launcher/ folder in mall4j project root" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Load modules
. (Join-Path $ModulesDir "EnvCheck.ps1")
. (Join-Path $ModulesDir "ConfigManager.ps1")
. (Join-Path $ModulesDir "ServiceManager.ps1")
. (Join-Path $ModulesDir "LogManager.ps1")

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
            Set-StepDirect -Id 2 -Status "running" -Text "Starting..."
            $portCheck = Check-Port -Port 6379
            if ($portCheck.InUse) {
                Write-LogDirect -Message "Redis already running" -Level "SUCCESS"
                Set-StepDirect -Id 2 -Status "completed" -Text "Already running"
                $script:Step = 3
            } else {
                Write-LogDirect -Message "Starting Redis (Docker)..." -Level "INFO"
                $script:StepJob = Start-Job -Name "step-redis" -ScriptBlock {
                    param($cb) function l { param($m) & $cb $m }
                    $r = docker rm -f yami-redis 2>&1 | Out-Null
                    $p = Start-Process -FilePath "docker" -ArgumentList "run -d --name yami-redis -p 6379:6379 redis:5.0.4" -NoNewWindow -PassThru
                    if (-not $p) { return "FAILED" }
                    $p.WaitForExit(20000)
                    start-sleep 3
                    $check = netstat -ano | Select-String LISTENING | Select-String ":6379 "
                    if ($check) { return "OK" } else { return "FAILED" }
                } -ArgumentList $logCb
            }
        }
        3 {  # Build backend - start the build
            Set-StepDirect -Id 3 -Status "running" -Text "Building..."
            Set-Status -Text "Building backend (~1-3 min)..." -Color "#FFC300"
            Write-LogDirect -Message "Building backend..." -Level "INFO"
            $script:StepBuildResult = $null
            $script:StepJob = Start-Job -Name "step-build" -ScriptBlock {
                param($root)
                $logFile = "$env:TEMP\mall4j_build.log"
                $p = Start-Process -FilePath "mvn" -ArgumentList "clean package -DskipTests" -NoNewWindow -PassThru -WorkingDirectory $root -RedirectStandardOutput $logFile -RedirectStandardError "${logFile}.err"
                if (-not $p) { return "FAILED" }
                $p.WaitForExit(300000)
                if ($p.ExitCode -eq 0) { return "OK" } else { return "FAILED" }
            } -ArgumentList $script:ProjectRoot
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
            $p = Start-Process -FilePath "java" -WindowStyle Hidden -ArgumentList "-jar -Dspring.profiles.active=dev -Xms512m -Xmx512m `"$jarFile`"" -PassThru -RedirectStandardOutput $logFile -RedirectStandardError "${logFile}.err"
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
            $p = Start-Process -FilePath "java" -WindowStyle Hidden -ArgumentList "-jar -Dspring.profiles.active=dev -Xms512m -Xmx512m `"$jarFile`"" -PassThru -RedirectStandardOutput $logFile -RedirectStandardError "${logFile}.err"
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
