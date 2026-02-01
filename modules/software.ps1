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
# GPU Driver Detection + Light Install via Windows Update
# ============================================================================

function Get-GpuVendors {
    $vendors = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
    try {
        $gpus = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop
    }
    catch {
        $gpus = @()
    }

    foreach ($gpu in $gpus) {
        $name = @($gpu.Name, $gpu.AdapterCompatibility) -join " "
        if ($name -match "NVIDIA") { $null = $vendors.Add("NVIDIA") }
        if ($name -match "AMD|Radeon") { $null = $vendors.Add("AMD") }
        if ($name -match "Intel") { $null = $vendors.Add("Intel") }
    }

    return $vendors.ToArray()
}

function Install-GpuDriverUpdates {
    param([string[]]$Vendors)

    if (-not $Vendors -or $Vendors.Count -eq 0) {
        Write-Host "  [!] No supported GPU vendor detected. Skipping driver updates." -ForegroundColor Yellow
        return
    }

    $vendorRegex = ($Vendors | ForEach-Object { [regex]::Escape($_) }) -join "|"
    Write-Host "  --> Checking GPU driver updates via Windows Update for: $($Vendors -join ', ')" -ForegroundColor Blue

    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $searchResult = $searcher.Search("IsInstalled=0 and Type='Driver'")

        if ($searchResult.Updates.Count -eq 0) {
            Write-Host "  [OK] No driver updates available" -ForegroundColor Green
            return
        }

        $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
        for ($i = 0; $i -lt $searchResult.Updates.Count; $i++) {
            $update = $searchResult.Updates.Item($i)
            $title = $update.Title

            $matchesVendor = $title -match $vendorRegex
            $matchesDisplay = $title -match "(Display|Graphics|Video|VGA|GPU|Radeon|GeForce|Quadro|Arc|Iris)"

            $matchesCategory = $false
            foreach ($category in $update.Categories) {
                if ($category.Name -match "(Display|Graphics|Video)") {
                    $matchesCategory = $true
                    break
                }
            }

            if ($matchesVendor -and ($matchesDisplay -or $matchesCategory)) {
                $null = $updatesToInstall.Add($update)
            }
        }

        if ($updatesToInstall.Count -eq 0) {
            Write-Host "  [OK] No matching GPU driver updates found" -ForegroundColor Green
            return
        }

        for ($i = 0; $i -lt $updatesToInstall.Count; $i++) {
            if (-not $updatesToInstall.Item($i).EulaAccepted) {
                $updatesToInstall.Item($i).AcceptEula()
            }
        }

        Write-Host "    Downloading driver updates..." -ForegroundColor DarkGray
        $downloader = $session.CreateUpdateDownloader()
        $downloader.Updates = $updatesToInstall
        $downloadResult = $downloader.Download()

        if ($downloadResult.ResultCode -ne 2) {
            Write-Host "  [!] Driver download result: $($downloadResult.ResultCode)" -ForegroundColor Yellow
        }

        Write-Host "    Installing driver updates..." -ForegroundColor DarkGray
        $installer = $session.CreateUpdateInstaller()
        $installer.Updates = $updatesToInstall
        $installResult = $installer.Install()

        if ($installResult.ResultCode -eq 2) {
            Write-Host "  [OK] GPU driver updates installed" -ForegroundColor Green
        }
        else {
            Write-Host "  [!] GPU driver install result: $($installResult.ResultCode)" -ForegroundColor Yellow
        }

        if ($installResult.RebootRequired) {
            Write-Host "  [!] Reboot required to complete driver updates" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  [X] GPU driver update check failed: $($_.Exception.Message)" -ForegroundColor Red
    }
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
# GPU Drivers (Core group)
# ============================================================================

if ($includeCore) {
    Write-Host "  --> Detecting GPU and installing light driver updates..." -ForegroundColor Blue
    $gpuVendors = Get-GpuVendors
    Install-GpuDriverUpdates -Vendors $gpuVendors
}
else {
    Write-Host "  --> Skipping GPU driver updates (Core not selected)" -ForegroundColor DarkGray
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
# Fan Control (Core group)
# ============================================================================

if ($includeCore) {
    Write-Host "  --> Downloading Fan Control..." -ForegroundColor Blue

    try {
        $fanRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/Rem0o/FanControl.Releases/releases/latest" -UseBasicParsing -Headers @{ "User-Agent" = "autoconfig" } -ErrorAction Stop
        $fanAssets = $fanRelease.assets

        $fanAsset = $fanAssets | Where-Object { $_.name -match "FanControl.*\.zip$" } | Select-Object -First 1
        if (-not $fanAsset) {
            $fanAsset = $fanAssets | Where-Object { $_.name -match ".*Setup.*\.exe$" } | Select-Object -First 1
        }
        if (-not $fanAsset) {
            $fanAsset = $fanAssets | Where-Object { $_.name -match "FanControl.*\.exe$" } | Select-Object -First 1
        }

        if ($fanAsset) {
            $fanPath = "$TempDir\$($fanAsset.name)"
            Invoke-WebRequest -Uri $fanAsset.browser_download_url -OutFile $fanPath -UseBasicParsing -ErrorAction Stop

            if ($fanAsset.name -match "\.zip$") {
                $fanInstallDir = "$env:ProgramFiles\FanControl"
                if (-not (Test-Path $fanInstallDir)) {
                    New-Item -ItemType Directory -Path $fanInstallDir -Force | Out-Null
                }

                Expand-Archive -Path $fanPath -DestinationPath $fanInstallDir -Force
                Write-Host "  [OK] Fan Control extracted to $fanInstallDir" -ForegroundColor Green
            }
            else {
                Start-Process -FilePath $fanPath -Wait
                Write-Host "  [OK] Fan Control installer launched" -ForegroundColor Green
            }
        }
        else {
            Write-Host "  [X] Fan Control asset not found in release" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  [X] Fan Control failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "  --> Skipping Fan Control (Core not selected)" -ForegroundColor DarkGray
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
