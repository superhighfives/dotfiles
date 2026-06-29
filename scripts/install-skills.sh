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
# Format: `<source> [skill-name ...]` (defaults to `*`).
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

# install_skill <source> [skill1 skill2 ...]  (default: *)
install_skill() {
  local src="$1"; shift
  local names=("$@")
  [[ ${#names[@]} -eq 0 ]] && names=('*')
  echo ">> installing ${names[*]} from $src for: ${agents[*]}"
  npx -y skills add "$src" \
    --global \
    --agent "${agents[@]}" \
    --skill "${names[@]}" \
    --yes
}

install_skill vercel-labs/agent-skills \
  vercel-composition-patterns \  # compound components, render props, context
  vercel-react-best-practices \  # React/Next.js performance patterns
  vercel-react-view-transitions \ # View Transition API for route/shared-element animations
  web-design-guidelines \        # UI/accessibility review checklist
  writing-guidelines             # docs/prose style and voice review

install_skill zeke/faster-chrome-devtools-skill  # Chrome DevTools Protocol automation (CDP)
install_skill diffusionstudio/lottie              # Lottie animation integration patterns

local_file="${HOME}/.skills.local"
if [[ -f "$local_file" ]]; then
  echo ">> reading $local_file"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    # shellcheck disable=SC2206
    parts=($line)
    src="${parts[0]}"
    DISABLE_TELEMETRY=1 install_skill "$src" "${parts[@]:1}"
  done < "$local_file"
fi

echo
echo "done. update later with: npx skills update -g"
