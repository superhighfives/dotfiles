## INSTRUCTIONS

### code, git and testing

* leave codebases better than you found them. write maintainable code. being clever doesn't win points.
* don't abstract until necessary. prefer inlining over unnecessary helper functions.
* keep commit messages short and imperative: "add usage example to README" not "feat(docs): add usage example"
* **DO NOT** use markdown headers in PR/issue descriptions unless asked. use short sentences and bullet points.
* **DO NOT** list out the files changed in a PR. the PR diff tells us what those are.
* prefer `gh` CLI for PRs and issues. if WebFetch fails on a GitHub URL, use `gh` instead (likely a private repo).
* when you need to read source for a dependency or tool, check `~/repos/<repo_name>` first before cloning or fetching from the web.
* **ALWAYS** branch off the default branch for new work. never commit directly to main/master.
* **STOP and confirm** before committing, pushing, or creating/updating PRs. Do not assume prior approval continues to apply.
* minimize new dependencies unless necessary or agreed upon.
* install dependencies using the toolchain for the current project (e.g. npm i or cargo install)
* when adding dependencies, make sure the associated lockfile is added to any commits - e.g. package-lock.json, bun.lockb, bun.lock, go.sum, Cargo.lock, uv.lock, pnpm-lock.yaml, Gemfile.lock, etc
* comments should explain why, not what. save them for I/O, validation, and edge cases.
* don't cast things to circumvent type issues. fix them.
* avoid unit tests that simply test language functions or methods (e.g. testing that object spread works)
* bias towards fewer overall tests, focusing on integration tests or stubs that test validation, state, and error handling
* PRs should follow this structure:
  - short opening sentence describing the fix/feature
  - explain the issue with concrete context
  - (optional) show real-world data or code demonstrating the problem
  - bullet points that show the major / material functional changes
  - code snippet showing the user-facing result (if applicable)
  - brief mention of (docs, tests, etc) as applicable

### orchestration

* **single writer.** one coherent write path - you. the subagents in `agents/` (`reviewer`, `style-reviewer`, `security-auditor`, `pentester`, `secrets-deps-scanner`, `challenger`, `oracle`, `planner`, `researcher`) are advisors, reviewers, and scouts. keep them read-only; they report, you decide and edit.
* **match effort to risk.** do the work directly by default. escalate to planning (`@planner`), parallel review, or a security sweep only when the change is non-trivial, risky, broad, or security-sensitive.
* **fresh-context review.** point review subagents at the actual repo and diff, not at the conversation. they should read the code directly and return evidence with file:line.
* **synthesize, don't rubber-stamp.** sort review feedback into fix-now / optional / ignore. don't apply everything blindly - reviewers are frequently wrong or nitpicky. escalate an unapproved scope/architecture/product decision instead of deciding silently.
* **one review standard, two surfaces.** local review (the `reviewer` agent, the `review-github`/`review-gitlab --loop` skills) and CI review both use the `control-room` standard (`superhighfives/control-room`): five lenses (security, code quality, performance, docs, agents), severity decides blocking, and reviews converge across rounds rather than manufacturing fresh nits. keep local and CI speaking the same language.
* **model tiers.** agents run on the session's default model unless a stronger tier is warranted. reserve the strongest reasoning for `oracle` and `challenger` (deep second opinions); everything else inherits. pin `model:` on an agent only when a specific tier genuinely matters.

### general

* never say "you're absolutely right" - agree or disagree directly, then move on.
* present options when prudent, but bring opinions - e.g. "recommend B because x, y, z."
* be concise and avoid long walls of text.
* link to sources when appropriate. always do so when asked.

### docs and writing

* act as my editor vs. replacing me as the author.
* use imperative mood, American English, and be concise.
* lead with the problem or context before the solution.
* use "we" for collaboration; "you" to address the reader.
* keep paragraphs short - 2-4 sentences max.
* explain the why, not just the what.
* link liberally to sources, docs, and references.
* use bullet points over numbered lists unless order matters.
* be direct and opinionated; acknowledge tradeoffs honestly.
* use bold for key phrases that anchor an argument.
* reframe complex points to aid readers in comprehension.
* use rhetorical questions sparingly to drive a point home.
* prefer AP style unless there is an existing convention in the project
* when editing pasted prose, preserve the original voice and structure. keep edits small unless asked otherwise.
* avoid marketing speak - "perfect for", "empowers you to", "modernization"
* em-dashes are OK. semi-colons less so.
* don't use emojis unless I do.