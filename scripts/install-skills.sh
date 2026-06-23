#!/usr/bin/env bash
# Install agent skills globally via the `skills` CLI (https://skills.sh).
# Symlinks into each agent's global skills dir, so re-running this script
# (or `npx skills update -g`) refreshes every agent in place.
#
# Usage:
#   scripts/install-skills.sh                # opencode + claude-code
#   scripts/install-skills.sh --skip-personal  # opencode only

set -euo pipefail

skip_personal=false
for arg in "$@"; do
  case "$arg" in
    --skip-personal) skip_personal=true ;;
    -h|--help)
      sed -n '2,9p' "$0"
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

# Each entry: "<source> <skill1,skill2,...>"
# Use '*' to install all skills from the source.
skills=(
  "vercel-labs/agent-skills vercel-composition-patterns,vercel-react-best-practices,vercel-react-view-transitions,web-design-guidelines,writing-guidelines"
)

for entry in "${skills[@]}"; do
  src="${entry%% *}"
  names="${entry#* }"
  echo ">> installing $names from $src for: $agents_csv"
  npx -y skills add "$src" \
    --global \
    --agent "$agents_csv" \
    --skill "$names" \
    --yes
done

# Private Cloudflare skills (telemetry disabled).
private_skills=(
  "git@gitlab.cfdata.org:sscott/make-the-change-easy.git *"
)

for entry in "${private_skills[@]}"; do
  src="${entry%% *}"
  names="${entry#* }"
  echo ">> installing $names from $src for: $agents_csv"
  DISABLE_TELEMETRY=1 npx -y skills add "$src" \
    --global \
    --agent "$agents_csv" \
    --skill "$names" \
    --yes
done

echo
echo "done. update later with: npx skills update -g"
