# Windows-side companion to install.sh.
#
# On Windows, the dev environment (zsh, Homebrew, mise, CLI tools, dotfiles)
# lives in WSL and is set up by install.sh. This script handles the native
# Windows half: GUI apps via winget (the Windows equivalent of the Brewfile
# casks) and Zed's settings, which Windows Zed reads from %APPDATA%\Zed rather
# than ~/.config/zed.
#
# Usage (from PowerShell, no admin needed - winget prompts for UAC per app):
#   powershell -ExecutionPolicy Bypass -File windows\install.ps1 [-SkipPersonal]
#
# Safe to run repeatedly: installed apps are skipped, and existing Zed
# settings are backed up before being replaced.

param(
  [switch]$SkipPersonal,
  [switch]$SkipApps,                      # only do the Zed and WSL steps
  [string]$WslUser = 'superhighfives'     # created if WSL's default user is root
)

$DotfilesDir = Split-Path -Parent $PSScriptRoot

function Write-Step($msg)    { Write-Host "`n-> $msg" -ForegroundColor Yellow }
function Write-Ok($msg)      { Write-Host "  [ok] $msg" -ForegroundColor Green }
function Write-Info($msg)    { Write-Host "  [i] $msg" -ForegroundColor Cyan }
function Write-Fail($msg)    { Write-Host "  [x] $msg" -ForegroundColor Red }

# Apps: "Id|Source". Mirrors the Brewfile casks where a Windows build exists.
# Store apps use their Microsoft Store product ID with the msstore source.
$CoreApps = @(
  'AgileBits.1Password|winget'
  'Discord.Discord|winget'
  'Figma.Figma|winget'
  'GitHub.GitHubDesktop|winget'
  'Google.Chrome|winget'
  'Google.CloudSDK|winget'
  'cjpais.Handy|winget'
  'Microsoft.PowerToys|winget'          # launcher (Command Palette), window tools
  'Microsoft.WindowsTerminal|winget'    # terminal (Ghostty has no Windows build)
  'Obsidian.Obsidian|winget'
  'Postman.Postman|winget'
  '9PFXXSHC64H3|msstore'                # Raycast
  'ZedIndustries.Zed|winget'
)

$PersonalApps = @(
  'Anthropic.Claude|winget'
  '9PLM9XGG6VKS|msstore'                # ChatGPT (OpenAI)
  'Ollama.Ollama|winget'
  '9NKSQGP7F2NH|msstore'                # WhatsApp
  'calibre.calibre|winget'
  'Plex.Plex|winget'
  'PrivateInternetAccess.PrivateInternetAccess|winget'
  'Fork.Fork|winget'
  'Tailscale.Tailscale|winget'
  'Cyanfish.NAPS2|winget'
)

function Install-App($entry) {
  $id, $source = $entry -split '\|'
  winget list --id $id --exact --source $source --accept-source-agreements --disable-interactivity | Out-Null
  if ($LASTEXITCODE -eq 0) {
    Write-Ok "$id already installed"
    return
  }
  Write-Info "Installing $id..."
  winget install --id $id --exact --source $source --accept-package-agreements --accept-source-agreements --disable-interactivity
  # winget reports "already installed" / "no newer version" as non-zero codes
  # (0x8A150061, 0x8A15002B) when `list` didn't match the install source.
  $alreadyInstalled = @(-1978335135, -1978335189)
  if ($LASTEXITCODE -eq 0) { Write-Ok "$id installed" }
  elseif ($alreadyInstalled -contains $LASTEXITCODE) { Write-Ok "$id already installed" }
  else { Write-Fail "$id failed (exit $LASTEXITCODE) - skipping" }
}

# --- Apps ---
Write-Step 'Installing apps with winget'
if ($SkipApps) {
  Write-Info 'Skipping apps (-SkipApps)'
} elseif (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Fail 'winget not found - install "App Installer" from the Microsoft Store and re-run'
  exit 1
} else {
  $CoreApps | ForEach-Object { Install-App $_ }

  if ($SkipPersonal) {
    Write-Info 'Skipping personal apps (-SkipPersonal)'
  } else {
    $PersonalApps | ForEach-Object { Install-App $_ }
  }
}

# --- Zed settings ---
# Copied rather than symlinked: Windows symlinks need Developer Mode or admin,
# and links into \\wsl$ paths are unreliable. Re-run this script after
# changing the tracked settings.
Write-Step 'Copying Zed settings'
$ZedSource = Join-Path $DotfilesDir '.config\zed'
$ZedTarget = Join-Path $env:APPDATA 'Zed'
New-Item -ItemType Directory -Force -Path $ZedTarget | Out-Null
foreach ($f in 'settings.json', 'keymap.json') {
  $src = Join-Path $ZedSource $f
  $dst = Join-Path $ZedTarget $f
  if (-not (Test-Path $src)) { continue }
  if ((Test-Path $dst) -and ((Get-FileHash $src).Hash -eq (Get-FileHash $dst).Hash)) {
    Write-Ok "$f already up to date"
    continue
  }
  if (Test-Path $dst) {
    $backup = "$dst.bak-$(Get-Date -Format yyyyMMddHHmmss)"
    Copy-Item $dst $backup
    Write-Info "Backed up existing $f to $backup"
  }
  Copy-Item $src $dst -Force
  Write-Ok "Copied $f"
}

# --- WSL user ---
# A distro installed without a first interactive launch (e.g. over SSH) never
# runs the create-a-user step, so it logs in as root - which install.sh refuses
# (Homebrew won't run as root). Offer to create the user and make it the
# default. This never runs `wsl --shutdown`: that stops every distro and
# anything running in them, so it's left for you to do when it's safe.
Write-Step 'Checking WSL'
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
  Write-Info 'WSL not installed - run: wsl --install -d Ubuntu-24.04'
} else {
  $current = (wsl.exe -- whoami | Out-String).Trim()
  if (-not $current) {
    Write-Info 'No WSL distro found - run: wsl --install -d Ubuntu-24.04'
  } elseif ($current -ne 'root') {
    Write-Ok "Default WSL user: $current"
  } elseif ($WslUser -notmatch '^[a-z_][a-z0-9_-]{0,31}$') {
    Write-Fail "'$WslUser' isn't a valid Linux username (lowercase letters, digits, - and _)"
  } else {
    Write-Info "Your default WSL user is root. install.sh needs a regular user."
    $answer = Read-Host "  Create WSL user '$WslUser' and make it the default? [Y/n]"
    if ($answer -match '^[nN]') {
      Write-Info 'Skipped - see the Windows (WSL) section of the README to do it by hand'
    } else {
      wsl.exe -u root -e id -u $WslUser 2>$null | Out-Null
      if ($LASTEXITCODE -eq 0) {
        Write-Ok "User $WslUser already exists"
      } else {
        Write-Info "Creating $WslUser - choose a password (sudo will ask for it)"
        wsl.exe -u root -e adduser $WslUser
      }
      wsl.exe -u root -e id -u $WslUser 2>$null | Out-Null
      if ($LASTEXITCODE -ne 0) {
        Write-Fail "Couldn't create $WslUser"
      } else {
        wsl.exe -u root -e usermod -aG sudo $WslUser
        Write-Ok "$WslUser can use sudo"
        # Append, never overwrite: wsl.conf may hold other sections (e.g.
        # [boot] systemd=true, which Docker needs).
        wsl.exe -u root -e sh -c 'grep -qs ^default= /etc/wsl.conf || printf ''\n[user]\ndefault=%s\n'' $1 >> /etc/wsl.conf' sh $WslUser
        $set = (wsl.exe -u root -e sh -c 'grep ^default= /etc/wsl.conf' | Out-String).Trim()
        if ($set -eq "default=$WslUser") {
          Write-Ok "Default user set in /etc/wsl.conf"
        } else {
          Write-Fail "/etc/wsl.conf already sets a different default ($set) - left unchanged"
        }
        Write-Info 'This takes effect the next time WSL starts. When nothing important is'
        Write-Info 'running in WSL, run `wsl --shutdown`, then reopen Ubuntu and run install.sh.'
      }
    }
  }
}

Write-Host @"

All done.

Manual steps remaining:
  1. Geist Mono (Zed's buffer font) isn't on winget - install it from
     https://github.com/vercel/geist-font/releases
  2. Set Windows Terminal's default profile to your WSL distro.

"@
