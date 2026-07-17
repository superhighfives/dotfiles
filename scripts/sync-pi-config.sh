#!/usr/bin/env bash
# Merge pi's tracked base config with any local overlay and write the result
# to ~/.pi/agent/. Pi doesn't natively support layered config, so this script
# renders the merged file for it.
#
# For each pair (settings, mcp):
#   dotfiles/pi/<name>.base.json         (tracked, shared across machines)
# + ~/.pi/agent/<name>.local.json        (untracked, per-machine, optional)
# = ~/.pi/agent/<name>.json              (rendered; pi reads this)
#
# Merge rules:
#   - Objects: deep-merged recursively, local wins on scalar conflicts.
#   - Arrays: base + local, deduped, order preserved (first occurrence).
#   - This lets ~/.pi/agent/settings.local.json add packages without repeating
#     the shared ones from the base file.
#
# Pi may write back to settings.json (e.g. lastChangelogVersion). Re-running
# this script clobbers those in-place mutations — acceptable cost for a
# predictable, idempotent render.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BASE_DIR="${DOTFILES_DIR}/pi"
PI_DIR="${HOME}/.pi/agent"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found — install it (brew install jq) and re-run" >&2
  exit 1
fi

mkdir -p "${PI_DIR}"

merge_config() {
  local name="$1"
  local base_file="${BASE_DIR}/${name}.base.json"
  local local_file="${PI_DIR}/${name}.local.json"
  local out_file="${PI_DIR}/${name}.json"

  if [[ ! -f "${base_file}" ]]; then
    echo "  base ${base_file} missing — skipping ${name}"
    return
  fi

  local overlay="{}"
  if [[ -f "${local_file}" ]]; then
    overlay="$(cat "${local_file}")"
  fi

  jq -n \
    --slurpfile base "${base_file}" \
    --argjson overlay "${overlay}" '
      def deepmerge(a; b):
        if b == null then a
        elif a == null then b
        elif (a|type) == "object" and (b|type) == "object" then
          reduce (b | keys_unsorted[]) as $k
            (a; .[$k] = deepmerge(.[$k]; b[$k]))
        elif (a|type) == "array" and (b|type) == "array" then
          reduce (a + b)[] as $x
            ([]; if any(.[]; . == $x) then . else . + [$x] end)
        else b
        end;
      deepmerge($base[0]; $overlay)
    ' > "${out_file}.tmp"
  mv "${out_file}.tmp" "${out_file}"
  if [[ -f "${local_file}" ]]; then
    echo "  rendered ${out_file} (base + ${name}.local.json)"
  else
    echo "  rendered ${out_file} (base only)"
  fi
}

merge_config settings
merge_config mcp
