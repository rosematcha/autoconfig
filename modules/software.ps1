<#
.SYNOPSIS
    Software installation module - Winget packages and custom downloads
#>

param(
    [ValidateSet("Core", "Dev")]
    [string[]]$SoftwareGroups = @("Core", "Dev")
)

$TempDir = "$env:TEMP\autoconfig"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
catch {
    # Best-effort only
}

if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
}

$includeCore = $SoftwareGroups -contains "Core"
$includeDev = $SoftwareGroups -contains "Dev"

if (-not ($includeCore -or $includeDev)) {
    Write-Host "  [!] No software groups selected. Skipping software module." -ForegroundColor Yellow
    return
}

# ============================================================================
# Winget Packages
# ============================================================================

Write-Host "  --> Installing winget packages..." -ForegroundColor Blue

$wingetPackages = @()
if ($includeCore) {
    $wingetPackages += @(
        "7zip.7zip",
        "Mozilla.Firefox",
        "Bitwarden.Bitwarden",
        "Discord.Discord",
        "OBSProject.OBSStudio"
    )
}

if ($includeDev) {
    $wingetPackages += @(
        "OpenJS.NodeJS",
        "Microsoft.VisualStudioCode",
        "Google.Antigravity",
        "Ubiquiti.WiFimanDesktop"
    )
}

$wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
if (-not $wingetCommand) {
    Write-Host "  [!] winget not found. Skipping winget packages." -ForegroundColor Yellow
}
elseif ($wingetPackages.Count -eq 0) {
    Write-Host "  [!] No winget packages selected." -ForegroundColor Yellow
}
else {
    $alreadyInstalledCodes = @([int]0x8A15000B, [int]0x8A15000D)
    foreach ($package in $wingetPackages) {
        Write-Host "    Installing $package..." -ForegroundColor DarkGray
        try {
            winget install -e --id $package --accept-source-agreements --accept-package-agreements --silent --disable-interactivity 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    [OK] $package" -ForegroundColor Green
            }
            elseif ($alreadyInstalledCodes -contains $LASTEXITCODE) {
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
}

# ============================================================================
# GitHub Desktop (Dev group)
# ============================================================================

if ($includeDev) {
    Write-Host "  --> Installing GitHub Desktop..." -ForegroundColor Blue

    $githubDesktopPath = "$TempDir\GitHubDesktopSetup.exe"
    $githubDesktopUrls = @(
        "https://central.github.com/deployments/desktop/desktop/latest/win64",
        "https://central.github.com/deployments/desktop/desktop/latest/win32"
    )

    try {
        $downloaded = $false
        foreach ($url in $githubDesktopUrls) {
            try {
                Invoke-WebRequest -Uri $url -OutFile $githubDesktopPath -UseBasicParsing -ErrorAction Stop
                $downloaded = $true
                break
            }
            catch {
                $lastError = $_
            }
        }

        if (-not $downloaded) {
            throw $lastError
        }

        Start-Process -FilePath $githubDesktopPath -ArgumentList "--silent" -Wait
        Write-Host "  [OK] GitHub Desktop installed" -ForegroundColor Green
    }
    catch {
        Write-Host "  [X] GitHub Desktop failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "  --> Skipping GitHub Desktop (Dev not selected)" -ForegroundColor DarkGray
}

# ============================================================================
# Helium Browser
# ============================================================================

if ($includeCore) {
    Write-Host "  --> Installing Helium browser..." -ForegroundColor Blue

    try {
        $heliumRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/nicholasballin/helium-windows/releases/latest" -UseBasicParsing -Headers @{ "User-Agent" = "autoconfig" } -ErrorAction Stop
        $heliumAsset = $heliumRelease.assets | Where-Object { $_.name -like "helium_*_x64-installer.exe" } | Select-Object -First 1
        
        if ($heliumAsset) {
            $heliumPath = "$TempDir\$($heliumAsset.name)"
            Invoke-WebRequest -Uri $heliumAsset.browser_download_url -OutFile $heliumPath -UseBasicParsing -ErrorAction Stop
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
}
else {
    Write-Host "  --> Skipping Helium browser (Core not selected)" -ForegroundColor DarkGray
}

# ============================================================================
# VLC 4.0 Nightly
# ============================================================================

if ($includeCore) {
    Write-Host "  --> Installing VLC 4.0 Nightly..." -ForegroundColor Blue

    try {
        $nightlyIndexUrl = "https://artifacts.videolan.org/vlc/nightly-win64/"
        $nightlyPage = Invoke-WebRequest -Uri $nightlyIndexUrl -UseBasicParsing -ErrorAction Stop

        $folderMatches = [regex]::Matches($nightlyPage.Content, 'href="(\d{8}-\d{4}/)"')
        $folders = $folderMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Descending -Unique
        $latestFolder = $folders | Select-Object -First 1

        if ($latestFolder) {
            Write-Host "    Found latest build: $latestFolder" -ForegroundColor DarkGray

            $buildPage = Invoke-WebRequest -Uri "$nightlyIndexUrl$latestFolder" -UseBasicParsing -ErrorAction Stop
            $installerMatches = [regex]::Matches($buildPage.Content, 'href="(vlc-[^"]*win64\.exe)"')
            $installers = $installerMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
            $installer = $installers | Where-Object { $_ -notmatch 'debug' } | Select-Object -First 1
            if (-not $installer) { $installer = $installers | Select-Object -First 1 }

            if ($installer) {
                $vlcUrl = "$nightlyIndexUrl$latestFolder$installer"
                $vlcPath = "$TempDir\$installer"

                Write-Host "    Downloading $installer..." -ForegroundColor DarkGray
                Invoke-WebRequest -Uri $vlcUrl -OutFile $vlcPath -UseBasicParsing -ErrorAction Stop

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
}
else {
    Write-Host "  --> Skipping VLC Nightly (Core not selected)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  [OK] Software installation complete" -ForegroundColor Green
