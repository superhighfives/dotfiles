---
name: review-gitlab
description: Review open review discussions on the current GitLab MR (from any reviewer - Opencode / AI Code Reviewer, Duo, human, etc.), decide whether each should be fixed, apply the fix, and reply inline. Use when the user says "review gitlab", "address MR feedback", "work through MR discussions", or wants to close out review threads on a GitLab merge request.
metadata:
  author: superhighfives
  version: "1.0.0"
---

# Review GitLab MR discussions

Work through unresolved inline discussions on a GitLab merge request - regardless of author (Opencode / AI Code Reviewer, GitLab Duo, other bots, humans). For each one: judge whether it should be fixed, apply the fix if so, and reply in the thread so it records what happened.

## Preconditions

Run these first; bail with a clear message if any fail:

- `glab auth status` - `glab` is authenticated (install: `brew install glab`)
- `git rev-parse --is-inside-work-tree` - inside a repo
- an MR exists for the current branch: `glab mr view --output json` (if none, tell the user and stop)

Capture the project path (`.references.full` up to the `!`) and MR IID (`.iid`). URL-encode the project path for API calls (`%2F` for `/`).

## Steps

1. **Fetch unresolved inline discussions** on the MR:

   ```
   glab api --paginate "projects/{url_encoded_project}/merge_requests/{iid}/discussions" \
     | jq '.[] | select(.resolved != true)
           | . as $d | .notes[0] as $n
           | select($n.position != null)
           | {discussion_id: $d.id, note_id: $n.id, user: $n.author.username,
              path: $n.position.new_path, line: $n.position.new_line,
              body: $n.body, url: $n.web_url, replies: (.notes[1:] | map({user:.author.username, body}))}'
   ```

   `position != null` filters out summary/overview notes that aren't tied to a line. `resolved != true` skips already-closed threads.

2. **Filter** to threads that actually need your attention:
   - Skip threads where the last note is from you (or already acknowledges a fix).
   - Skip threads where a human has already replied in a way that supersedes the bot's ask.

3. **Show the user the list** - for each discussion: author, file:line, one-line summary, and `{mr_url}#note_{note_id}`. State how many you found before touching any code.

4. **Work through each discussion in order.** For each one:

   - Read the referenced `path` around `line` to understand context.
   - Use the `make-the-change-easy` skill to decide: **fix**, **already-correct**, or **won't-fix**. Do not blindly apply suggestions - reviewers (bots and humans) are frequently wrong, nitpicky, or unaware of constraints elsewhere in the codebase. Reject changes that introduce bugs, break local patterns, or contradict user intent. Ask the user before applying anything genuinely judgement-call.
   - If fixing, make the minimal edit that resolves the issue and matches surrounding style.
   - Keep a running note of the resolution for the reply.

5. **Reply to each discussion** with the resolution, threaded under the original note:

   ```
   glab api "projects/{url_encoded_project}/merge_requests/{iid}/discussions/{discussion_id}/notes" \
     -f body='<resolution>'
   ```

   Keep replies short and factual - no markdown headers. Examples:
   - `Fixed in <short-sha or "the next commit"> - <one line on the change>.`
   - `Not changing this: <reason>.`
   - `Already handled by <where> - no change needed.`

   Post the reply right after you've decided/edited for that discussion.

6. **Do not resolve discussions.** Post the reply and move on - let the reviewer (or user) resolve. The reply itself is the record of what happened.

7. **Commit and push the fixes** once every discussion is addressed. Only if `git status --porcelain` is non-empty:

   ```
   git add -A
   git commit -m "Address MR review feedback"
   git push
   ```

   If the branch has no upstream yet, use `git push -u origin HEAD`.

8. **Summarize** for the user: counts of fixed / won't-fix / already-correct (broken down by reviewer if useful), files changed, pushed commit sha. Note that bot reviewers will re-review on the next pipeline.

## Confirmation rule

- Apply code edits, then commit and push them - this is the expected end state, no need to ask.
- Do **not** merge the MR - that's the user's call.
- For judgement-call fixes with real trade-offs, ask the user before applying. Don't push something you're unsure about.

## Notes

- Overview / summary notes (a bot's top-level MR comment) have `position: null` and are filtered out. If a summary raises something the inline discussions don't, mention it in the final summary rather than trying to reply to it.
- Only `notes[0]` is the finding - anything after is prior replies from humans or the bot itself. Use those `replies` to decide whether the thread is really still open.
- Discussions on lines that have since changed may show an outdated `position` - check the current file; if the code no longer exists, reply that it's been superseded.
- `glab api` mirrors `gh api`; use `--paginate` on MRs with many discussions.
