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
  [switch]$SkipPersonal
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
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Fail 'winget not found - install "App Installer" from the Microsoft Store and re-run'
  exit 1
}
$CoreApps | ForEach-Object { Install-App $_ }

if ($SkipPersonal) {
  Write-Info 'Skipping personal apps (-SkipPersonal)'
} else {
  $PersonalApps | ForEach-Object { Install-App $_ }
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

# --- WSL sanity check ---
# A distro with no user created on first launch logs in as root, which
# install.sh refuses (Homebrew won't run as root).
Write-Step 'Checking WSL'
if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
  $wslUser = (wsl.exe -- whoami | Out-String).Trim()
  if ($wslUser -eq 'root') {
    Write-Fail 'Your default WSL user is root. Create a regular user before running install.sh (see README).'
  } elseif ($wslUser) {
    Write-Ok "Default WSL user: $wslUser"
  } else {
    Write-Info 'No WSL distro found - run: wsl --install -d Ubuntu-24.04'
  }
} else {
  Write-Info 'WSL not installed - run: wsl --install -d Ubuntu-24.04'
}

Write-Host @"

All done.

Manual steps remaining:
  1. Geist Mono (Zed's buffer font) isn't on winget - install it from
     https://github.com/vercel/geist-font/releases
  2. 1Password > Settings > Developer: enable the SSH agent (and WSL
     integration) to use your SSH key for git in WSL.
  3. Set Windows Terminal's default profile to your WSL distro.

"@
