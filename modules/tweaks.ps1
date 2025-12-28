<#
.SYNOPSIS
    System tweaks module - Winutil automation and OneDrive removal
#>

$BaseUrl = "https://windows.rosematcha.com"

# ============================================================================
# OneDrive Aggressive Removal
# ============================================================================

Write-Host "  --> Removing OneDrive..." -ForegroundColor Blue

# Kill OneDrive processes
Get-Process -Name "OneDrive*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# Uninstall OneDrive
$oneDrivePaths = @(
    "$env:SystemRoot\System32\OneDriveSetup.exe",
    "$env:SystemRoot\SysWOW64\OneDriveSetup.exe",
    "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDriveSetup.exe"
)

foreach ($path in $oneDrivePaths) {
    if (Test-Path $path) {
        Start-Process $path -ArgumentList "/uninstall" -Wait -ErrorAction SilentlyContinue
        break
    }
}

# Remove OneDrive from Explorer sidebar
$explorerKeys = @(
    "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}",
    "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
)

foreach ($key in $explorerKeys) {
    if (Test-Path $key) {
        Set-ItemProperty -Path $key -Name "System.IsPinnedToNameSpaceTree" -Value 0 -ErrorAction SilentlyContinue
    }
}

# Remove OneDrive scheduled tasks
Get-ScheduledTask -TaskPath '\' -TaskName 'OneDrive*' -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

# Remove OneDrive startup entry
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive" -ErrorAction SilentlyContinue

# Remove OneDrive folders
$oneDriveFolders = @(
    "$env:LOCALAPPDATA\Microsoft\OneDrive",
    "$env:PROGRAMDATA\Microsoft OneDrive",
    "$env:SYSTEMDRIVE\OneDriveTemp"
)

foreach ($folder in $oneDriveFolders) {
    if (Test-Path $folder) {
        Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Disable OneDrive via Group Policy
$oneDriveGPO = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
if (-not (Test-Path $oneDriveGPO)) {
    New-Item -Path $oneDriveGPO -Force | Out-Null
}
Set-ItemProperty -Path $oneDriveGPO -Name "DisableFileSyncNGSC" -Value 1 -Type DWord

Write-Host "  [OK] OneDrive removed" -ForegroundColor Green

# ============================================================================
# Winutil Tweaks
# ============================================================================

Write-Host "  --> Downloading Winutil configuration..." -ForegroundColor Blue

# Download winutil config
$winutilConfig = "$env:TEMP\autoconfig\winutil.json"
try {
    Invoke-WebRequest -Uri "$BaseUrl/config/winutil.json" -OutFile $winutilConfig -UseBasicParsing
    Write-Host "  [OK] Winutil config downloaded" -ForegroundColor Green
}
catch {
    Write-Host "  [X] Failed to download Winutil config: $($_.Exception.Message)" -ForegroundColor Red
    return
}

Write-Host "  --> Running Winutil with configuration..." -ForegroundColor Blue
Write-Host "    This may take several minutes..." -ForegroundColor DarkGray

try {
    # Run Winutil with config
    $winutilCommand = "& { `$(irm https://christitus.com/win) } -Config `"$winutilConfig`" -Run"
    Invoke-Expression $winutilCommand
    Write-Host "  [OK] Winutil tweaks applied" -ForegroundColor Green
}
catch {
    Write-Host "  [X] Winutil failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ============================================================================
# Additional Manual Tweaks
# ============================================================================

Write-Host "  --> Applying additional tweaks..." -ForegroundColor Blue

# Disable Cortana
$cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
if (-not (Test-Path $cortanaPath)) {
    New-Item -Path $cortanaPath -Force | Out-Null
}
Set-ItemProperty -Path $cortanaPath -Name "AllowCortana" -Value 0 -Type DWord

# Disable Web Search in Start Menu
Set-ItemProperty -Path $cortanaPath -Name "DisableWebSearch" -Value 1 -Type DWord
Set-ItemProperty -Path $cortanaPath -Name "ConnectedSearchUseWeb" -Value 0 -Type DWord

# Disable Bing in Start Menu
$bingPath = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
if (-not (Test-Path $bingPath)) {
    New-Item -Path $bingPath -Force | Out-Null
}
Set-ItemProperty -Path $bingPath -Name "DisableSearchBoxSuggestions" -Value 1 -Type DWord

# Show file extensions
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Type DWord

# Show hidden files
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1 -Type DWord

# Disable Windows Copilot
$copilotPath = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
if (-not (Test-Path $copilotPath)) {
    New-Item -Path $copilotPath -Force | Out-Null
}
Set-ItemProperty -Path $copilotPath -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord

# Disable Recall
$recallPath = "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI"
if (-not (Test-Path $recallPath)) {
    New-Item -Path $recallPath -Force | Out-Null
}
Set-ItemProperty -Path $recallPath -Name "DisableAIDataAnalysis" -Value 1 -Type DWord

Write-Host "  [OK] Additional tweaks applied" -ForegroundColor Green
