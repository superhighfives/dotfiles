#!/usr/bin/env bash
# Install agent skills globally via the `skills` CLI (https://skills.sh).
# Symlinks into each agent's global skills dir, so re-running this script
# (or `npx skills update -g`) refreshes every agent in place.
#
# Usage:
#   scripts/install-skills.sh                  # opencode + claude-code
#   scripts/install-skills.sh --skip-personal  # opencode only (work machines)
#
# Tracked cross-machine skill sources go in .skills at the dotfiles repo root.
# Work- or machine-specific (private) sources go in ~/.skills.local.
# Both use the same format: one entry per line, blank lines and `#` comments
# ignored. Format: `<source> [skill-name ...]` (defaults to `*`).
# Entries from ~/.skills.local run with DISABLE_TELEMETRY=1.

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

# read_skills_file <path> [env-prefix]
# env-prefix is prepended to install_skill (e.g. "DISABLE_TELEMETRY=1")
read_skills_file() {
  local file="$1"
  local env_prefix="${2:-}"
  [[ -f "$file" ]] || return 0
  echo ">> reading $file"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    # shellcheck disable=SC2206
    parts=($line)
    src="${parts[0]}"
    if [[ -n "$env_prefix" ]]; then
      # shellcheck disable=SC2163
      export $env_prefix
      install_skill "$src" "${parts[@]:1}"
      unset "${env_prefix%%=*}"
    else
      install_skill "$src" "${parts[@]:1}"
    fi
  done < "$file"
}

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
read_skills_file "${repo_root}/.skills"
read_skills_file "${HOME}/.skills.local" "DISABLE_TELEMETRY=1"

echo
echo "done. update later with: npx skills update -g"
