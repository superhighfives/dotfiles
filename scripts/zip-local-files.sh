#!/usr/bin/env bash
# Archive supported per-machine overlays from the home directory.

set -euo pipefail

archive_name="local-files-$(date +%Y%m%d-%H%M%S).zip"
archive_path="${PWD}/${archive_name}"
supported_files=(
  ".zshrc.local"
  ".gitconfig.local"
  ".config/opencode/opencode.local.jsonc"
  "Brewfile.local"
  ".skills.local"
  ".pi/agent/settings.local.json"
  ".pi/agent/mcp.local.json"
  ".npmrc.local"
)
files=()

for file in "${supported_files[@]}"; do
  [[ -f "${HOME}/${file}" ]] && files+=("$file")
done

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No supported local overlay files found in the home directory."
  exit 1
fi

(
  cd "$HOME"
  zip "$archive_path" "${files[@]}"
)

echo "Created: $archive_path"
printf '  %s\n' "${files[@]}"
