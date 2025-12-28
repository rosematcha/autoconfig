<#
.SYNOPSIS
    Windows Auto-Configuration Script
    
.DESCRIPTION
    Activates Windows, applies privacy/performance tweaks, installs software,
    and deploys personal configuration files.
    
.PARAMETER Unattended
    Run without any confirmation prompts
    
.PARAMETER SkipActivation
    Skip Windows activation (for corporate/pre-activated machines)
    
.PARAMETER SkipTweaks
    Skip Winutil tweaks and OneDrive removal
    
.PARAMETER SkipSoftware
    Skip software installation (winget + custom downloads)
    
.PARAMETER SkipConfigs
    Skip deploying configuration files
    
.PARAMETER SkipSSH
    Skip SSH Server setup
    
.PARAMETER SkipWSL
    Skip WSL installation
    
.EXAMPLE
    irm https://windows.rosematcha.com/ | iex
    
.EXAMPLE
    .\index.ps1 -Unattended -SkipActivation
    
.NOTES
    Author: Reese
    Repository: https://github.com/[username]/autoconfig
#>

param(
    [switch]$Unattended,
    [switch]$SkipActivation,
    [switch]$SkipTweaks,
    [switch]$SkipSoftware,
    [switch]$SkipConfigs,
    [switch]$SkipSSH,
    [switch]$SkipWSL
)

# ============================================================================
# Configuration
# ============================================================================

$BaseUrl = "https://windows.rosematcha.com"
$TempDir = "$env:TEMP\autoconfig"

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host ">> " -ForegroundColor Cyan -NoNewline
    Write-Host $Message -ForegroundColor White
    Write-Host ("-" * 60) -ForegroundColor DarkGray
}

function Write-Success {
    param([string]$Message)
    Write-Host "  [OK] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Info {
    param([string]$Message)
    Write-Host "  --> " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  [!] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Err {
    param([string]$Message)
    Write-Host "  [X] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Confirm-Step {
    param([string]$Message)
    
    if ($Unattended) { return $true }
    
    Write-Host ""
    Write-Host "  ? " -ForegroundColor Magenta -NoNewline
    Write-Host "$Message " -NoNewline
    Write-Host "[Y/n] " -ForegroundColor DarkGray -NoNewline
    
    $response = Read-Host
    return ($response -eq "" -or $response -match "^[Yy]")
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-RemoteScript {
    param(
        [string]$Url,
        [hashtable]$Parameters = @{}
    )
    
    try {
        $script = Invoke-RestMethod -Uri $Url -UseBasicParsing
        $scriptBlock = [ScriptBlock]::Create($script)
        & $scriptBlock @Parameters
    }
    catch {
        Write-Err "Failed to execute remote script: $Url"
        Write-Err $_.Exception.Message
        return $false
    }
    return $true
}

# ============================================================================
# Banner
# ============================================================================

Clear-Host
Write-Host @"

  +-----------------------------------------------------------+
  |                                                           |
  |   Windows Auto-Configuration Script                       |
  |   windows.rosematcha.com                                  |
  |                                                           |
  +-----------------------------------------------------------+

"@ -ForegroundColor Cyan

# Show active flags
$activeFlags = @()
if ($Unattended) { $activeFlags += "Unattended" }
if ($SkipActivation) { $activeFlags += "SkipActivation" }
if ($SkipTweaks) { $activeFlags += "SkipTweaks" }
if ($SkipSoftware) { $activeFlags += "SkipSoftware" }
if ($SkipConfigs) { $activeFlags += "SkipConfigs" }
if ($SkipSSH) { $activeFlags += "SkipSSH" }
if ($SkipWSL) { $activeFlags += "SkipWSL" }

if ($activeFlags.Count -gt 0) {
    Write-Host "  Flags: " -ForegroundColor DarkGray -NoNewline
    Write-Host ($activeFlags -join ", ") -ForegroundColor Yellow
    Write-Host ""
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

Write-Step "Pre-flight Checks"

# Check for admin privileges
if (-not (Test-Administrator)) {
    Write-Warn "Not running as Administrator. Elevating..."
    
    $scriptPath = $MyInvocation.MyCommand.Path
    if ($scriptPath) {
        # Running from file
        $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        if ($Unattended) { $argList += " -Unattended" }
        if ($SkipActivation) { $argList += " -SkipActivation" }
        if ($SkipTweaks) { $argList += " -SkipTweaks" }
        if ($SkipSoftware) { $argList += " -SkipSoftware" }
        if ($SkipConfigs) { $argList += " -SkipConfigs" }
        if ($SkipSSH) { $argList += " -SkipSSH" }
        if ($SkipWSL) { $argList += " -SkipWSL" }
        
        Start-Process powershell.exe -ArgumentList $argList -Verb RunAs
    }
    else {
        # Running from irm | iex - need to re-download with elevation
        $flags = ""
        if ($Unattended) { $flags += " -Unattended" }
        if ($SkipActivation) { $flags += " -SkipActivation" }
        if ($SkipTweaks) { $flags += " -SkipTweaks" }
        if ($SkipSoftware) { $flags += " -SkipSoftware" }
        if ($SkipConfigs) { $flags += " -SkipConfigs" }
        if ($SkipSSH) { $flags += " -SkipSSH" }
        if ($SkipWSL) { $flags += " -SkipWSL" }
        
        $command = "irm $BaseUrl | iex"
        if ($flags) {
            $command = "`$params = @{$($flags.Trim().Replace(' -', ';') -replace ';(\w+)', '$1=$true')}; iex `"& { `$(irm $BaseUrl) } @params`""
        }
        
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$command`"" -Verb RunAs
    }
    exit
}

Write-Success "Running as Administrator"

# Create temp directory
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
}
Write-Success "Temp directory ready: $TempDir"

# ============================================================================
# Step 1: Windows Activation
# ============================================================================

if (-not $SkipActivation) {
    Write-Step "Windows Activation (MAS)"
    
    if (Confirm-Step "Activate Windows using MAS (HWID + Ohook)?") {
        Write-Info "Running Microsoft Activation Scripts..."
        try {
            & ([ScriptBlock]::Create((Invoke-RestMethod https://get.activated.win))) /HWID /Ohook /S
            Write-Success "Windows activation complete"
        }
        catch {
            Write-Err "Activation failed: $($_.Exception.Message)"
        }
    }
    else {
        Write-Info "Skipping Windows activation"
    }
}
else {
    Write-Step "Windows Activation"
    Write-Info "Skipped (SkipActivation flag)"
}

# ============================================================================
# Step 2: System Tweaks
# ============================================================================

if (-not $SkipTweaks) {
    Write-Step "System Tweaks (Winutil + OneDrive Removal)"
    
    if (Confirm-Step "Apply privacy/performance tweaks and remove OneDrive?") {
        Write-Info "Downloading tweaks module..."
        Invoke-RemoteScript -Url "$BaseUrl/modules/tweaks.ps1"
    }
    else {
        Write-Info "Skipping system tweaks"
    }
}
else {
    Write-Step "System Tweaks"
    Write-Info "Skipped (SkipTweaks flag)"
}

# ============================================================================
# Step 3: Software Installation
# ============================================================================

if (-not $SkipSoftware) {
    Write-Step "Software Installation"
    
    if (Confirm-Step "Install software packages?") {
        Write-Info "Downloading software module..."
        Invoke-RemoteScript -Url "$BaseUrl/modules/software.ps1"
    }
    else {
        Write-Info "Skipping software installation"
    }
}
else {
    Write-Step "Software Installation"
    Write-Info "Skipped (SkipSoftware flag)"
}

# ============================================================================
# Step 4: SSH Server
# ============================================================================

if (-not $SkipSSH) {
    Write-Step "SSH Server Setup"
    
    if (Confirm-Step "Enable SSH Server?") {
        Write-Info "Installing OpenSSH Server..."
        try {
            $sshCapability = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
            if ($sshCapability.State -ne "Installed") {
                Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
                Write-Success "OpenSSH Server installed"
            }
            else {
                Write-Success "OpenSSH Server already installed"
            }
            
            # Start and enable the service
            Start-Service sshd -ErrorAction SilentlyContinue
            Set-Service -Name sshd -StartupType Automatic
            Write-Success "SSH Server enabled and set to auto-start"
            
            # Configure firewall
            $firewallRule = Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
            if (-not $firewallRule) {
                New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
                Write-Success "Firewall rule created"
            }
        }
        catch {
            Write-Err "SSH setup failed: $($_.Exception.Message)"
        }
    }
    else {
        Write-Info "Skipping SSH setup"
    }
}
else {
    Write-Step "SSH Server Setup"
    Write-Info "Skipped (SkipSSH flag)"
}

# ============================================================================
# Step 5: WSL
# ============================================================================

if (-not $SkipWSL) {
    Write-Step "Windows Subsystem for Linux"
    
    if (Confirm-Step "Install WSL?") {
        Write-Info "Installing WSL..."
        try {
            wsl --install --no-launch
            Write-Success "WSL installed (reboot required to complete)"
        }
        catch {
            Write-Err "WSL installation failed: $($_.Exception.Message)"
        }
    }
    else {
        Write-Info "Skipping WSL installation"
    }
}
else {
    Write-Step "Windows Subsystem for Linux"
    Write-Info "Skipped (SkipWSL flag)"
}

# ============================================================================
# Step 6: Configuration Files
# ============================================================================

if (-not $SkipConfigs) {
    Write-Step "Configuration Files"
    
    if (Confirm-Step "Deploy personal configuration files?") {
        Write-Info "Downloading configs module..."
        Invoke-RemoteScript -Url "$BaseUrl/modules/configs.ps1"
    }
    else {
        Write-Info "Skipping configuration deployment"
    }
}
else {
    Write-Step "Configuration Files"
    Write-Info "Skipped (SkipConfigs flag)"
}

# ============================================================================
# Cleanup & Summary
# ============================================================================

Write-Step "Complete"

# Cleanup temp directory
if (Test-Path $TempDir) {
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host @"

  +-----------------------------------------------------------+
  |                                                           |
  |   Setup Complete!                                         |
  |                                                           |
  |   A system restart is recommended.                        |
  |                                                           |
  +-----------------------------------------------------------+

"@ -ForegroundColor Green

if (-not $Unattended) {
    Write-Host "  Press any key to exit..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
