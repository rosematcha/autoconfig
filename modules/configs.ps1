<#
.SYNOPSIS
    Configuration files deployment module
#>

$BaseUrl = "https://windows.rosematcha.com"
$TempDir = "$env:TEMP\autoconfig"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
catch {
    # Best-effort only
}

# ============================================================================
# VS Code Configuration
# ============================================================================

Write-Host "  --> Configuring VS Code..." -ForegroundColor Blue

$vscodeUserDir = "$env:APPDATA\Code\User"

# Create VS Code user directory if it doesn't exist
if (-not (Test-Path $vscodeUserDir)) {
    New-Item -ItemType Directory -Path $vscodeUserDir -Force | Out-Null
}

# Download and apply settings.json
try {
    $settingsPath = "$vscodeUserDir\settings.json"
    Invoke-WebRequest -Uri "$BaseUrl/config/vscode-settings.json" -OutFile $settingsPath -UseBasicParsing -ErrorAction Stop
    Write-Host "    [OK] VS Code settings.json deployed" -ForegroundColor Green
}
catch {
    Write-Host "    [X] Failed to deploy VS Code settings: $($_.Exception.Message)" -ForegroundColor Red
}

# Install VS Code extensions
try {
    $extensionsContent = Invoke-RestMethod -Uri "$BaseUrl/config/vscode-extensions.txt" -UseBasicParsing -ErrorAction Stop
    $extensions = $extensionsContent -split "`n" | Where-Object { $_.Trim() -ne "" }
    
    $codeCommand = Get-Command code -ErrorAction SilentlyContinue
    $codeExecutable = $null
    if ($codeCommand) {
        $codeExecutable = $codeCommand.Source
    }
    if (-not $codeExecutable) {
        $codeCandidates = @(
            "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
            "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
            "$env:ProgramFiles(x86)\Microsoft VS Code\bin\code.cmd"
        )
        foreach ($candidate in $codeCandidates) {
            if (Test-Path $candidate) {
                $codeExecutable = $candidate
                break
            }
        }
    }

    if (-not $codeExecutable) {
        Write-Host "    [!] VS Code CLI not found. Skipping extension install." -ForegroundColor Yellow
    }
    else {
        Write-Host "    Installing extensions..." -ForegroundColor DarkGray
        foreach ($ext in $extensions) {
            $ext = $ext.Trim()
            if ($ext -and -not $ext.StartsWith("#")) {
                & $codeExecutable --install-extension $ext --force 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "      [OK] $ext" -ForegroundColor DarkGreen
                }
                else {
                    Write-Host "      [!] $ext (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
                }
            }
        }
        Write-Host "    [OK] VS Code extensions installed" -ForegroundColor Green
    }
}
catch {
    Write-Host "    [X] Failed to install extensions: $($_.Exception.Message)" -ForegroundColor Red
}

# ============================================================================
# OpenCode Configuration
# ============================================================================

Write-Host "  --> Configuring OpenCode..." -ForegroundColor Blue

$opencodeDir = "$env:USERPROFILE\.config\opencode"

# Create OpenCode config directory if it doesn't exist
if (-not (Test-Path $opencodeDir)) {
    New-Item -ItemType Directory -Path $opencodeDir -Force | Out-Null
}

# Download and apply opencode.json
try {
    $opencodeConfig = "$opencodeDir\opencode.json"
    Invoke-WebRequest -Uri "$BaseUrl/config/opencode.json" -OutFile $opencodeConfig -UseBasicParsing -ErrorAction Stop
    Write-Host "    [OK] OpenCode config deployed" -ForegroundColor Green
}
catch {
    Write-Host "    [X] Failed to deploy OpenCode config: $($_.Exception.Message)" -ForegroundColor Red
}

# ============================================================================
# Firefox Configuration
# ============================================================================

Write-Host "  --> Configuring Firefox..." -ForegroundColor Blue

# Find Firefox profile directory
$firefoxProfilesDir = "$env:APPDATA\Mozilla\Firefox\Profiles"

if (Test-Path $firefoxProfilesDir) {
    # Get the default profile (or the first one if no default)
    $profiles = Get-ChildItem -Path $firefoxProfilesDir -Directory | Where-Object { $_.Name -like "*default*" -or $_.Name -like "*release*" }
    
    if (-not $profiles) {
        $profiles = Get-ChildItem -Path $firefoxProfilesDir -Directory | Select-Object -First 1
    }
    
    if ($profiles) {
        foreach ($profile in $profiles) {
            try {
                $userJsPath = Join-Path $profile.FullName "user.js"
                Invoke-WebRequest -Uri "$BaseUrl/config/firefox-user.js" -OutFile $userJsPath -UseBasicParsing -ErrorAction Stop
                Write-Host "    [OK] Firefox user.js deployed to $($profile.Name)" -ForegroundColor Green
            }
            catch {
                Write-Host "    [X] Failed to deploy to $($profile.Name): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    else {
        Write-Host "    [!] No Firefox profile found. Run Firefox once to create a profile." -ForegroundColor Yellow
    }
}
else {
    Write-Host "    [!] Firefox not installed or never run. Skipping Firefox config." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  [OK] Configuration deployment complete" -ForegroundColor Green
