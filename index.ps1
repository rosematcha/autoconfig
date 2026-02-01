<#
.SYNOPSIS
    Windows Auto-Configuration Script
    
.DESCRIPTION
    Activates Windows, applies privacy/performance tweaks, installs software,
    and deploys personal configuration files.
    
.PARAMETER Unattended
    Run without any confirmation prompts

.PARAMETER Skip
    Skip one or more steps (Activation, Tweaks, Software, Dev, Configs, SSH, WSL)

.PARAMETER Only
    Run only specific steps (Activation, Tweaks, Software, Dev, Configs, SSH, WSL)
    
.PARAMETER SkipActivation
    Legacy alias for -Skip Activation
    
.PARAMETER SkipTweaks
    Legacy alias for -Skip Tweaks
    
.PARAMETER SkipSoftware
    Legacy alias for -Skip Software
    
.PARAMETER SkipDev
    Legacy alias for -Skip Dev
    
.PARAMETER SkipConfigs
    Legacy alias for -Skip Configs
    
.PARAMETER SkipSSH
    Legacy alias for -Skip SSH
    
.PARAMETER SkipWSL
    Legacy alias for -Skip WSL
    
.EXAMPLE
    irm https://windows.rosematcha.com/ | iex
    
.EXAMPLE
    .\index.ps1 -Unattended -Skip Activation
    
.NOTES
    Author: Reese
    Repository: https://github.com/[username]/autoconfig
#>

param(
    [switch]$Unattended,

    [ValidateSet("Activation", "Tweaks", "Software", "Dev", "Configs", "SSH", "WSL")]
    [string[]]$Skip,

    [ValidateSet("Activation", "Tweaks", "Software", "Dev", "Configs", "SSH", "WSL")]
    [string[]]$Only,

    # Legacy flags (still supported)
    [switch]$SkipActivation,
    [switch]$SkipTweaks,
    [switch]$SkipSoftware,
    [switch]$SkipDev,
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

function Initialize-Tls {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
    catch {
        # Best-effort only; do not block execution
    }
}

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
        $script = Invoke-RestMethod -Uri $Url -UseBasicParsing -ErrorAction Stop
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
# Flag Normalization
# ============================================================================

$validSteps = @("Activation", "Tweaks", "Software", "Dev", "Configs", "SSH", "WSL")

$skipSet = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
$onlySet = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)

if ($Skip) {
    foreach ($item in $Skip) {
        if ($item) { $null = $skipSet.Add($item) }
    }
}

if ($Only) {
    foreach ($item in $Only) {
        if ($item) { $null = $onlySet.Add($item) }
    }
}

$legacyFlagsUsed = $false
if ($SkipActivation) { $null = $skipSet.Add("Activation"); $legacyFlagsUsed = $true }
if ($SkipTweaks) { $null = $skipSet.Add("Tweaks"); $legacyFlagsUsed = $true }
if ($SkipSoftware) { $null = $skipSet.Add("Software"); $legacyFlagsUsed = $true }
if ($SkipDev) { $null = $skipSet.Add("Dev"); $legacyFlagsUsed = $true }
if ($SkipConfigs) { $null = $skipSet.Add("Configs"); $legacyFlagsUsed = $true }
if ($SkipSSH) { $null = $skipSet.Add("SSH"); $legacyFlagsUsed = $true }
if ($SkipWSL) { $null = $skipSet.Add("WSL"); $legacyFlagsUsed = $true }

$useOnly = $onlySet.Count -gt 0

$orderedOnly = $validSteps | Where-Object { $onlySet.Contains($_) }
$orderedSkip = $validSteps | Where-Object { $skipSet.Contains($_) }

$runActivation = if ($useOnly) { $onlySet.Contains("Activation") } else { -not $skipSet.Contains("Activation") }
$runTweaks = if ($useOnly) { $onlySet.Contains("Tweaks") } else { -not $skipSet.Contains("Tweaks") }
$runConfigs = if ($useOnly) { $onlySet.Contains("Configs") } else { -not $skipSet.Contains("Configs") }
$runSSH = if ($useOnly) { $onlySet.Contains("SSH") } else { -not $skipSet.Contains("SSH") }
$runWSL = if ($useOnly) { $onlySet.Contains("WSL") } else { -not $skipSet.Contains("WSL") }

$includeCore = if ($useOnly) { $onlySet.Contains("Software") } else { -not $skipSet.Contains("Software") }
$includeDev = if ($useOnly) { $onlySet.Contains("Dev") } else { $includeCore -and -not $skipSet.Contains("Dev") }

if ($skipSet.Contains("Software")) { $includeCore = $false; $includeDev = $false }
if ($skipSet.Contains("Dev")) { $includeDev = $false }

$runSoftware = $includeCore -or $includeDev

$softwareGroups = @()
if ($includeCore) { $softwareGroups += "Core" }
if ($includeDev) { $softwareGroups += "Dev" }

function Get-RunArguments {
    param(
        [string[]]$OnlyList,
        [string[]]$SkipList,
        [switch]$Unattended
    )

    $args = @()
    if ($Unattended) { $args += "-Unattended" }
    foreach ($item in $OnlyList) {
        $args += "-Only"
        $args += $item
    }
    foreach ($item in $SkipList) {
        $args += "-Skip"
        $args += $item
    }
    return $args
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
if ($orderedOnly.Count -gt 0) { $activeFlags += ("Only: " + ($orderedOnly -join ", ")) }
if ($orderedSkip.Count -gt 0) { $activeFlags += ("Skip: " + ($orderedSkip -join ", ")) }

if ($activeFlags.Count -gt 0) {
    Write-Host "  Flags: " -ForegroundColor DarkGray -NoNewline
    Write-Host ($activeFlags -join " | ") -ForegroundColor Yellow
    Write-Host ""
}

if ($legacyFlagsUsed) {
    Write-Warn "Legacy skip flags detected. Prefer -Skip/-Only for new usage."
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

Write-Step "Pre-flight Checks"
Initialize-Tls

# Check for admin privileges
if (-not (Test-Administrator)) {
    Write-Warn "Not running as Administrator. Elevating..."
    
    $scriptPath = $MyInvocation.MyCommand.Path
    $runArgs = Get-RunArguments -OnlyList $orderedOnly -SkipList $orderedSkip -Unattended:$Unattended
    if ($scriptPath) {
        # Running from file
        $argList = @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            "`"$scriptPath`""
        )
        $argList += $runArgs
        Start-Process powershell.exe -ArgumentList ($argList -join " ") -Verb RunAs
    }
    else {
        # Running from irm | iex - need to re-download with elevation
        $commandArgs = $runArgs -join " "
        $command = "& { $(Invoke-RestMethod '$BaseUrl') }"
        if ($commandArgs) {
            $command += " $commandArgs"
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

if ($runActivation) {
    Write-Step "Windows Activation (MAS)"
    
    # Check if Windows is already activated
    $license = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "Name like 'Windows%'" -ErrorAction SilentlyContinue |
        Where-Object { $_.PartialProductKey } |
        Select-Object -First 1
    $licenseStatus = $license.LicenseStatus
    $isActivated = $licenseStatus -eq 1
    
    if ($isActivated) {
        Write-Success "Windows is already activated"
    }
    elseif ($null -eq $licenseStatus) {
        Write-Warn "Unable to determine activation status"
    }
    elseif (Confirm-Step "Activate Windows using MAS (HWID + Ohook)?") {
        Write-Info "Running Microsoft Activation Scripts..."
        try {
            & ([ScriptBlock]::Create((Invoke-RestMethod https://get.activated.win -ErrorAction Stop))) /HWID /Ohook /S
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
    Write-Info "Skipped (flags)"
}

# ============================================================================
# Step 2: System Tweaks
# ============================================================================

if ($runTweaks) {
    Write-Step "System Tweaks (Winutil + OneDrive Removal)"
    
    if (Confirm-Step "Apply privacy/performance tweaks and remove OneDrive?") {
        Write-Info "Downloading tweaks module..."
        if (-not (Invoke-RemoteScript -Url "$BaseUrl/modules/tweaks.ps1")) {
            Write-Warn "Tweaks module failed"
        }
    }
    else {
        Write-Info "Skipping system tweaks"
    }
}
else {
    Write-Step "System Tweaks"
    Write-Info "Skipped (flags)"
}

# ============================================================================
# Step 3: Software Installation
# ============================================================================

if ($runSoftware) {
    Write-Step "Software Installation"
    
    $softwareNote = if ($includeCore -and $includeDev) { "core + dev" } elseif ($includeDev) { "dev only" } else { "core only" }
    if (Confirm-Step "Install software packages ($softwareNote)?") {
        Write-Info "Downloading software module..."
        if (-not (Invoke-RemoteScript -Url "$BaseUrl/modules/software.ps1" -Parameters @{ SoftwareGroups = $softwareGroups })) {
            Write-Warn "Software module failed"
        }
    }
    else {
        Write-Info "Skipping software installation"
    }
}
else {
    Write-Step "Software Installation"
    Write-Info "Skipped (flags)"
}

# ============================================================================
# Step 4: SSH Server
# ============================================================================

if ($runSSH) {
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
    Write-Info "Skipped (flags)"
}

# ============================================================================
# Step 5: WSL
# ============================================================================

if ($runWSL) {
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
    Write-Info "Skipped (flags)"
}

# ============================================================================
# Step 6: Configuration Files
# ============================================================================

if ($runConfigs) {
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
    Write-Info "Skipped (flags)"
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
