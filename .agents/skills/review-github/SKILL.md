---
name: review-github
description: Review open review comments and threads on the current GitHub PR (from any reviewer - Copilot, Claude, human, etc.), decide whether each should be fixed, apply the fix, and reply inline. Use when the user says "review github", "address PR feedback", "work through PR comments", or wants to close out review threads on a GitHub PR.
metadata:
  author: superhighfives
  version: "3.0.0"
---

# Review GitHub PR comments and threads

Work through unresolved inline review comments on a GitHub pull request - regardless of author (Copilot, `claude`, other bots, humans). For each one: judge whether it should be fixed, apply the fix if so, and reply inline so the thread records what happened.

## Preconditions

Run these first; bail with a clear message if any fail:

- `gh auth status` - `gh` is authenticated
- `git rev-parse --is-inside-work-tree` - inside a repo
- a PR exists for the current branch: `gh pr view --json number,url,headRefName` (if none, tell the user and stop)

Capture `owner/repo` from `gh repo view --json owner,name -q '.owner.login + "/" + .name'` and the PR number for the API calls below.

## Steps

1. **Fetch unresolved review threads** via GraphQL (this respects "Resolve conversation" state, which the REST comments endpoint doesn't):

   ```
   gh api graphql -f query='
     query($owner:String!,$repo:String!,$number:Int!){
       repository(owner:$owner,name:$repo){
         pullRequest(number:$number){
           reviewThreads(first:100){
             nodes{
               id isResolved isOutdated
               comments(first:20){
                 nodes{ databaseId author{login} path line body url }
               }
             }
           }
         }
       }
     }' -f owner={owner} -f repo={repo} -F number={number} \
     --jq '.data.repository.pullRequest.reviewThreads.nodes[]
           | select(.isResolved==false)
           | {threadId:.id, outdated:.isOutdated,
              root:.comments.nodes[0], replies:(.comments.nodes[1:])}'
   ```

   Also glance at the top-of-PR review bodies (`gh pr view --json reviews`) - not threaded, but they sometimes carry blocking asks the inline threads don't.

2. **Filter** to threads that actually need your attention:
   - Skip threads where the last comment is from you (or already acknowledges a fix).
   - Keep outdated threads but flag them - the referenced code may have moved.

3. **Show the user the list** - for each thread: author of the root comment, file:line, one-line summary, thread URL (`root.url`). State how many you found before touching any code.

4. **Work through each thread in order.** For each one:

   - Read the referenced `path` around `line` to understand context.
   - Use the `make-the-change-easy` skill to decide: **fix**, **already-correct**, or **won't-fix**. Do not blindly apply suggestions - reviewers (bots and humans) are frequently wrong, nitpicky, or unaware of constraints elsewhere in the codebase. Reject changes that introduce bugs, break local patterns, or contradict user intent. Ask the user before applying anything genuinely judgement-call.
   - If fixing, make the minimal edit that resolves the issue and matches surrounding style.
   - Keep a running note of the resolution for the reply.

5. **Reply inline to each thread's root comment**, threaded under it:

   ```
   gh api repos/{owner}/{repo}/pulls/{number}/comments \
     -f body='<resolution>' -F in_reply_to=<root.databaseId>
   ```

   Keep replies short and factual - no markdown headers. Examples:
   - `Fixed in <short-sha or "the next commit"> - <one line on the change>.`
   - `Not changing this: <reason>.`
   - `Already handled by <where> - no change needed.`

   Post the reply right after you've decided/edited for that thread, so replies and fixes stay in sync.

6. **Do not resolve threads.** Post the reply and move on - let the reviewer (or user) resolve. The reply itself is the record of what happened.

7. **Commit and push the fixes** once every thread is addressed. Only if `git status --porcelain` is non-empty:

   ```
   git add -A
   git commit -m "Address PR review feedback"
   git push
   ```

   If the branch has no upstream yet, use `git push -u origin HEAD`.

8. **Summarize** for the user: counts of fixed / won't-fix / already-correct (broken down by reviewer if useful), files changed, pushed commit sha. Note that bot reviewers will re-review on the new commit.

## Confirmation rule

- Apply code edits, then commit and push them - this is the expected end state, no need to ask.
- Do **not** merge the PR - that's the user's call.
- For judgement-call fixes with real trade-offs, ask the user before applying. Don't push something you're unsure about.

## Notes

- Top-level PR review bodies (summary reviews) aren't threaded and have no `in_reply_to` target. If a summary raises something the inline threads don't, mention it in the final summary rather than trying to reply to it.
- Threads on lines that have since changed come back as `isOutdated: true` - check the current file; if the code no longer exists, reply that it's been superseded.
- Same issue across multiple threads: fix all instances, but still reply to each thread so each is closed out.
