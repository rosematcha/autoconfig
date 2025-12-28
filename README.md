# Reese's Windows Auto-Config

Setting up Windows is fun, but it can also suck. This script is designed to standardize my install process for Windows.

## Usage

The defaults of this app are set to my needs.

```powershell
irm https://windows.rosematcha.com/ | iex
```

For most people who are not me, I'd suggest adding the ``-SkipConfigs`` flag to skip adding my config files, and ``-SkipDev`` if you don't need developer tools. ``-Unattended`` is also nice to skip being prompted to confirm each step. 

```powershell
irm https://windows.rosematcha.com/ | iex -SkipConfigs -SkipDev -Unattended
```

## Flags

| Flag | Description |
|------|-------------|
| `-Unattended` | Run without confirmation prompts |
| `-SkipActivation` | Skip Windows activation (MAS) |
| `-SkipTweaks` | Skip Winutil tweaks & OneDrive removal |
| `-SkipSoftware` | Skip ALL software installation |
| `-SkipDev` | Skip dev tools (Node, VS Code, etc.) |
| `-SkipConfigs` | Skip config file deployment |
| `-SkipSSH` | Skip SSH Server setup |
| `-SkipWSL` | Skip WSL installation |

## What It Does

### 1. Windows Activation (MAS)
- HWID activation for Windows
- Ohook activation for Office
- Uses [Microsoft Activation Scripts](https://github.com/massgravel/Microsoft-Activation-Scripts)

### 2. System Tweaks
- Disable Cortana
- Disable web search in Start
- Show file extensions
- Show hidden files
- Disable Windows Copilot
- Disable Recall
- Most of the work is done by [Winutil](https://github.com/Winutil/Winutil).
<details>
  <summary>Click here for full details.</summary>
  - Create restore point
  - Disable telemetry
  - Disable unnecessary services
  - Disable GameDVR
  - Disable consumer features
  - Remove Copilot
  - Debloat Edge
  - Enable "End Task" on taskbar
  - Delete temp files
  - Add Ultimate Performance power plan
  - Remove OneDrive
</details>


### 3. Software Installation

#### Via Winget
- Node.js
- 7-Zip
- Firefox
- Bitwarden
- Discord
- OBS Studio
- VS Code
- Google Antigravity
- Ubiquiti WiFiman

#### Custom Downloads
- **GitHub Desktop** - Latest from GitHub CDN
- **Helium Browser** - Latest from GitHub releases
- **VLC 4.0 Nightly** - Latest from VideoLAN artifacts

### 4. SSH Server
- Install OpenSSH Server capability
- Enable and auto-start sshd service
- Configure firewall rule

### 5. WSL
- Install Windows Subsystem for Linux
- Requires reboot to complete

### 6. Configuration Files
- **VS Code**: settings.json + extensions
- **OpenCode**: Antigravity provider config
- **Firefox**: user.js with privacy settings

## Project Structure

```
autoconfig/
├── index.ps1                 # Main entry point
├── README.md
├── config/
│   ├── winutil.json          # Winutil automation config
│   ├── vscode-settings.json  # VS Code settings
│   ├── vscode-extensions.txt # VS Code extension IDs
│   ├── opencode.json         # OpenCode config
│   └── firefox-user.js       # Firefox preferences
└── modules/
    ├── tweaks.ps1            # Winutil + OneDrive removal
    ├── software.ps1          # Package installation
    └── configs.ps1           # Config file deployment
```

## Hosting

This project is designed to be hosted on Cloudflare Pages (or similar) with raw file access:

1. Push to GitHub repository
2. Connect to Cloudflare Pages
3. Set custom domain: `windows.rosematcha.com`
4. Ensure raw file serving (no HTML wrapper)

### Cloudflare Pages Setup

```toml
# wrangler.toml (if needed)
[site]
bucket = "./"
```

The main `index.ps1` must be served at the root URL for `irm | iex` to work.

## License

Personal use. Not intended for redistribution.
