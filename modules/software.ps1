<#
.SYNOPSIS
    Software installation module - Winget packages and custom downloads
#>

param(
    [switch]$SkipDev
)

$TempDir = "$env:TEMP\autoconfig"

# ============================================================================
# Winget Packages
# ============================================================================

Write-Host "  --> Installing winget packages..." -ForegroundColor Blue

# Core packages (always installed)
$wingetPackages = @(
    "7zip.7zip",
    "Mozilla.Firefox",
    "Bitwarden.Bitwarden",
    "Discord.Discord",
    "OBSProject.OBSStudio"
)

# Dev packages (skipped with -SkipDev)
if (-not $SkipDev) {
    $wingetPackages += @(
        "OpenJS.NodeJS",
        "Microsoft.VisualStudioCode",
        "Google.Antigravity",
        "Ubiquiti.WiFimanDesktop"
    )
}

foreach ($package in $wingetPackages) {
    Write-Host "    Installing $package..." -ForegroundColor DarkGray
    try {
        winget install -e --id $package --accept-source-agreements --accept-package-agreements --silent 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    [OK] $package" -ForegroundColor Green
        }
        elseif ($LASTEXITCODE -eq -1978335189) {
            Write-Host "    [OK] $package (already installed)" -ForegroundColor DarkGreen
        }
        else {
            Write-Host "    [!] $package (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "    [X] $package failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "  [OK] Winget packages complete" -ForegroundColor Green

# ============================================================================
# GitHub Desktop (skipped with -SkipDev)
# ============================================================================

if (-not $SkipDev) {
    Write-Host "  --> Installing GitHub Desktop..." -ForegroundColor Blue

    $githubDesktopUrl = "https://central.github.com/deployments/desktop/desktop/latest/win32"
    $githubDesktopPath = "$TempDir\GitHubDesktopSetup.exe"

    try {
        Invoke-WebRequest -Uri $githubDesktopUrl -OutFile $githubDesktopPath -UseBasicParsing
        Start-Process -FilePath $githubDesktopPath -ArgumentList "--silent" -Wait
        Write-Host "  [OK] GitHub Desktop installed" -ForegroundColor Green
    }
    catch {
        Write-Host "  [X] GitHub Desktop failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "  --> Skipping GitHub Desktop (SkipDev)" -ForegroundColor DarkGray
}

# ============================================================================
# Helium Browser
# ============================================================================

Write-Host "  --> Installing Helium browser..." -ForegroundColor Blue

try {
    $heliumRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/nicholasballin/helium-windows/releases/latest" -UseBasicParsing
    $heliumAsset = $heliumRelease.assets | Where-Object { $_.name -like "helium_*_x64-installer.exe" } | Select-Object -First 1
    
    if ($heliumAsset) {
        $heliumPath = "$TempDir\$($heliumAsset.name)"
        Invoke-WebRequest -Uri $heliumAsset.browser_download_url -OutFile $heliumPath -UseBasicParsing
        Start-Process -FilePath $heliumPath -ArgumentList "/S" -Wait
        Write-Host "  [OK] Helium browser installed" -ForegroundColor Green
    }
    else {
        Write-Host "  [X] Helium installer not found in release" -ForegroundColor Red
    }
}
catch {
    Write-Host "  [X] Helium failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ============================================================================
# VLC 4.0 Nightly
# ============================================================================

Write-Host "  --> Installing VLC 4.0 Nightly..." -ForegroundColor Blue

try {
    # Get the list of nightly builds
    $nightlyPage = Invoke-WebRequest -Uri "https://artifacts.videolan.org/vlc/nightly-win64/" -UseBasicParsing
    
    # Parse the dated folders (format: YYYYMMDD-XXXX)
    $folders = $nightlyPage.Links | 
        Where-Object { $_.href -match '^\d{8}-\d{4}/$' } | 
        Sort-Object { $_.href } -Descending |
        Select-Object -First 1
    
    if ($folders) {
        $latestFolder = $folders.href
        Write-Host "    Found latest build: $latestFolder" -ForegroundColor DarkGray
        
        # Get the installer from the latest folder
        $buildPage = Invoke-WebRequest -Uri "https://artifacts.videolan.org/vlc/nightly-win64/$latestFolder" -UseBasicParsing
        $installer = $buildPage.Links | 
            Where-Object { $_.href -like "vlc-*-win64.exe" } | 
            Select-Object -First 1
        
        if ($installer) {
            $vlcUrl = "https://artifacts.videolan.org/vlc/nightly-win64/$latestFolder$($installer.href)"
            $vlcPath = "$TempDir\$($installer.href)"
            
            Write-Host "    Downloading $($installer.href)..." -ForegroundColor DarkGray
            Invoke-WebRequest -Uri $vlcUrl -OutFile $vlcPath -UseBasicParsing
            
            Write-Host "    Running installer..." -ForegroundColor DarkGray
            Start-Process -FilePath $vlcPath -ArgumentList "/S" -Wait
            Write-Host "  [OK] VLC 4.0 Nightly installed" -ForegroundColor Green
        }
        else {
            Write-Host "  [X] VLC installer not found in $latestFolder" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  [X] No VLC nightly builds found" -ForegroundColor Red
    }
}
catch {
    Write-Host "  [X] VLC failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "  [OK] Software installation complete" -ForegroundColor Green
