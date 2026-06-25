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

# Reload modules in runspace
$modulesDir = Join-Path $ProjectRoot "launcher/modules"
. (Join-Path $modulesDir "EnvCheck.ps1")
. (Join-Path $modulesDir "ServiceManager.ps1")

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

    # ===== Step 4: Start admin Backend =====
    Set-StepUI -Id 4 -Status "running" -Text "Starting..."
    Set-StatusBarUI -Text "Starting admin backend..." -Color "#07C160"
    try {
        $adminResult = Start-BackendService -ServiceName "admin" -ProjectRoot $ProjectRoot -LogCallback $logCb
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
        $apiResult = Start-BackendService -ServiceName "api" -ProjectRoot $ProjectRoot -LogCallback $logCb
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
