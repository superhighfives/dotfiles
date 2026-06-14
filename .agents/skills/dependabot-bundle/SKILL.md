---
name: dependabot-bundle
description: Bundle all open dependabot PRs in the current repo into a single combined PR. Use when the user says "bundle dependabot PRs", "combine dependabot", "merge all dependabot updates", or wants to clear a backlog of automated dependency PRs in one shot.
metadata:
  author: superhighfives
  version: "1.0.0"
---

# Dependabot bundle

Combine every open dependabot PR in the current repo into one PR. When that PR merges, dependabot detects the upstream version bumps on its next run and closes the individual PRs itself — no extra cleanup step needed.

## Preconditions

Run these first; bail with a clear message if any fail:

- `gh auth status` — `gh` is authenticated
- `git rev-parse --is-inside-work-tree` — inside a repo
- working tree is clean (`git status --porcelain` is empty), otherwise ask the user to stash or commit
- a default branch exists (`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`)

## Steps

1. **List open dependabot PRs** targeting the default branch:

   ```
   gh pr list --state open --author "app/dependabot" \
     --json number,title,headRefName,url --limit 100
   ```

   If none, tell the user and stop. If one, tell the user and offer to just merge that PR directly instead of bundling.

2. **Show the user the list** (number, title, URL) and confirm before continuing. Mention that merging the bundle will let dependabot auto-close each individual PR on its next scheduled run.

3. **Sync the default branch and branch off it**:

   ```
   git fetch origin
   git switch <default-branch>
   git pull --ff-only
   git switch -c chore/bundle-dependabot-<YYYY-MM-DD>
   ```

4. **Cherry-pick each dependabot branch's commits** in order, preserving authorship:

   ```
   git fetch origin <headRefName>
   git cherry-pick origin/<headRefName>
   ```

   For most dependabot PRs the head ref is a single commit. If a cherry-pick conflicts (typically the lockfile), resolve by taking the bundle branch's lockfile and regenerating it once at the end — don't try to merge lockfile hunks manually.

5. **Regenerate the lockfile once** at the end based on the project's package manager. Detect by lockfile present in the repo root (`pnpm-lock.yaml` → pnpm, `bun.lock`/`bun.lockb` → bun, `package-lock.json` → npm, `yarn.lock` → yarn, `Cargo.lock` → cargo, `uv.lock` → uv, `Gemfile.lock` → bundle, `go.sum` → go). Run the matching install/lock command, then `git add` + `git commit` only if the lockfile changed.

6. **Push and open the PR**:

   ```
   git push -u origin HEAD
   gh pr create --base <default-branch> --title "chore: bundle dependabot updates" \
     --body "<see body template below>"
   ```

   Body template — no markdown headers, short opening sentence + bullets per [INSTRUCTIONS](~/.config/opencode/INSTRUCTIONS.md):

   ```
   Combines <N> open dependabot PRs into one merge.

   Dependabot will close each of these on its next run once the upstream
   versions land on <default-branch>:

   - #<n1> <title>
   - #<n2> <title>
   ...
   ```

7. **Return the new PR URL** and remind the user that the individual PRs stay open until dependabot's next scheduled run picks up the version bumps.

## Confirmation rule

Stop and ask the user before: creating the branch, pushing, or opening the PR. Do not merge the PR — that's the user's call.

## When not to use this

- Repo uses dependabot `groups:` config — those already bundle by ecosystem; check `.github/dependabot.yml` first and skip if groups cover everything open.
- Any dependabot PR has failing CI the user hasn't acknowledged — surface that and ask before including it. A bundle is only as green as its reddest member.
- Major-version bumps mixed with patch bumps — offer to split into two PRs (patch bundle + majors reviewed individually).
