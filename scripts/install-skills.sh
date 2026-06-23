#!/usr/bin/env bash
# Install agent skills globally via the `skills` CLI (https://skills.sh).
# Symlinks into each agent's global skills dir, so re-running this script
# (or `npx skills update -g`) refreshes every agent in place.
#
# Usage:
#   scripts/install-skills.sh                  # opencode + claude-code
#   scripts/install-skills.sh --skip-personal  # opencode only (work machines)
#
# Drop work- or machine-specific skill sources in ~/.skills.local.
# One per line, blank lines and `#` comments ignored.
# Format: `<source> [skill-names-csv]` (defaults to `*`).
# Local entries run with DISABLE_TELEMETRY=1.

set -euo pipefail

skip_personal=false
for arg in "$@"; do
  case "$arg" in
    --skip-personal) skip_personal=true ;;
    -h|--help)
      sed -n '2,13p' "$0"
      exit 0
      ;;
    *) echo "unknown arg: $arg" >&2; exit 1 ;;
  esac
done

agents=(opencode)
if ! $skip_personal; then
  agents+=(claude-code)
fi
agents_csv=$(IFS=,; echo "${agents[*]}")

# install_skill <source> <skill-names-csv-or-*>
install_skill() {
  local src="$1" names="${2:-*}"
  echo ">> installing $names from $src for: $agents_csv"
  npx -y skills add "$src" \
    --global \
    --agent "$agents_csv" \
    --skill "$names" \
    --yes
}

install_skill vercel-labs/agent-skills \
  vercel-composition-patterns,vercel-react-best-practices,vercel-react-view-transitions,web-design-guidelines,writing-guidelines

local_file="${HOME}/.skills.local"
if [[ -f "$local_file" ]]; then
  echo ">> reading $local_file"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    src="${line%% *}"
    names="*"
    [[ "$line" == *" "* ]] && names="${line#* }"
    DISABLE_TELEMETRY=1 install_skill "$src" "$names"
  done < "$local_file"
fi

echo
echo "done. update later with: npx skills update -g"
