#!/usr/bin/env bash
# config-drift.sh — surface .config entries git is silently ignoring.
#
# .gitignore uses an allowlist model for .config/: everything is dropped by the
# blanket `.config/*` rule unless a `!` line re-includes it. That keeps a newly
# installed tool from leaking secrets into this public repo, but it also means a
# fresh config is invisible until you notice it. This lists top-level .config
# entries that exist on disk yet are caught ONLY by the blanket rule — i.e. new
# things you haven't decided about — so you can either allowlist them
# (`!.config/<name>/`) or acknowledge them as intentional ignores.
#
# It also flags stale `!` allowlist lines pointing at paths that no longer exist.
#
# Usage: scripts/config-drift.sh
# Exit:  0 = clean, 1 = drift found (usable in a pre-commit hook or CI).

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

blanket=".config/*"
drift=()
stale=()

# --- New drift: on-disk .config entries caught only by the blanket rule ---
if [[ -d .config ]]; then
  for path in .config/* .config/.[!.]*; do
    [[ -e "$path" ]] || continue                       # skip non-matching globs
    [[ -n "$(git ls-files -- "$path")" ]] && continue  # tracked → a decided config
    rule="$(git check-ignore -v -- "$path" 2>/dev/null | head -n1 || true)"
    # rule = "<file>:<line>:<pattern>\t<path>"; take the pattern field
    pattern="$(printf '%s' "$rule" | cut -f1 | cut -d: -f3-)"
    [[ "$pattern" == "$blanket" ]] && drift+=("$path")
  done
fi

# --- Stale allowlist: `!` re-includes for .config paths that vanished ---
while IFS= read -r entry; do
  target="${entry#\!}"; target="${target%/}"
  [[ -e "$target" ]] || stale+=("$entry")
done < <(grep -E '^![[:space:]]*\.config/' .gitignore 2>/dev/null || true)

status=0

if [[ ${#drift[@]} -gt 0 ]]; then
  status=1
  echo "⚠  New .config entries ignored only by the blanket '$blanket' rule:"
  for p in "${drift[@]}"; do echo "     $p"; done
  echo
  echo "   Decide for each — edit .gitignore:"
  echo "     • track it       → add  '!<path>/'  under the tracked-configs list"
  echo "     • keep it hidden → add  '<path>/'   under acknowledged ignores"
  echo
fi

if [[ ${#stale[@]} -gt 0 ]]; then
  status=1
  echo "⚠  Stale allowlist lines in .gitignore (path no longer on disk):"
  for s in "${stale[@]}"; do echo "     $s"; done
  echo
fi

if [[ $status -eq 0 ]]; then
  echo "✓ .config in sync — every entry is tracked or explicitly acknowledged."
fi

exit $status
