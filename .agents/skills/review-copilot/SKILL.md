---
name: review-copilot
description: Review GitHub Copilot's feedback on the current PR, fix each issue in the working tree, and reply to each Copilot review comment with the fix. Use when the user says "review copilot", "address copilot feedback", "fix copilot comments", or wants to work through a Copilot code review on a PR.
metadata:
  author: superhighfives
  version: "1.0.0"
---

# Review Copilot feedback

Work through GitHub Copilot's automated code-review comments on a pull request: evaluate each one, apply the fix (or explain why not), and reply inline to that comment so the thread records what happened.

## Preconditions

Run these first; bail with a clear message if any fail:

- `gh auth status` — `gh` is authenticated
- `git rev-parse --is-inside-work-tree` — inside a repo
- a PR exists for the current branch: `gh pr view --json number,url,headRefName` (if none, tell the user and stop)

Capture `owner/repo` from `gh repo view --json owner,name -q '.owner.login + "/" + .name'` and the PR number for the API calls below.

## Steps

1. **Fetch Copilot's inline review comments** on the PR. Copilot posts as `copilot-pull-request-reviewer[bot]` (also shown as "Copilot"):

   ```
   gh api --paginate repos/{owner}/{repo}/pulls/{number}/comments \
     --jq '.[] | select(.user.login == "copilot-pull-request-reviewer[bot]")
           | {id, path, line, body, url, in_reply_to_id}'
   ```

   Only top-level comments (`in_reply_to_id` is null) are Copilot's findings — skip anything that's already a reply. If none, tell the user there's no Copilot feedback to address and stop.

2. **Show the user the list** — for each comment: file:line, a one-line summary, and the comment URL. State how many you found before touching any code.

3. **Work through each comment in order.** For each one:

   - Read the referenced `path` around `line` to understand the context before judging.
   - Decide: **fix**, **already-correct**, or **won't-fix**. Copilot is frequently wrong or nitpicky — do not blindly apply suggestions. If a suggestion would introduce a bug, break a pattern used elsewhere in the file, or contradict the user's intent, don't apply it.
   - If fixing, make the minimal edit that resolves the issue, matching surrounding style.
   - Keep a running note of the resolution (what you did, or why you didn't) for the reply.

4. **Reply inline to each Copilot comment** with the resolution, threaded under the original:

   ```
   gh api repos/{owner}/{repo}/pulls/{number}/comments \
     -f body='<resolution>' -F in_reply_to=<comment_id>
   ```

   Keep replies short and factual — no markdown headers. Examples:
   - `Fixed in <short-sha or "the next commit"> — <one line on the change>.`
   - `Not changing this: <reason>.`
   - `Already handled by <where> — no change needed.`

   Post the reply for a comment right after you've decided/edited for it, so replies and fixes stay in sync.

5. **Commit and push the fixes** once every comment is addressed, so the PR updates and Copilot re-reviews. Only if there are actual code changes (`git status --porcelain` is non-empty):

   ```
   git add -A
   git commit -m "Address Copilot review feedback"
   git push
   ```

   Use a commit message that reflects what changed if it's narrow enough to summarize; otherwise the generic message above is fine. If the branch has no upstream yet, push with `git push -u origin HEAD`.

6. **Summarize** for the user: counts of fixed / won't-fix / already-correct, the files changed, and the pushed commit sha. Note that Copilot will re-review on the new commit.

## Confirmation rule

- Apply code edits, then commit and push them — this is the expected end state, no need to ask.
- Do **not** merge the PR — that's the user's call.
- If Copilot flags something ambiguous or a fix would be a judgement call with real trade-offs, ask the user before applying rather than guessing. Don't push a fix you're unsure about.

## Notes

- Copilot's summary review body (the top-of-PR overview) is not an inline comment and has no thread to reply to — focus on the inline comments. Mention the summary only if it raises something the inline comments don't.
- If the same issue recurs across several comments, fix all instances but still reply to each comment so every thread is resolved.
- Comments on lines that have since changed may come back as "outdated" — check the current file state; if the code Copilot referenced no longer exists, reply noting it's been superseded.
