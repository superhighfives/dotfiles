# PI AGENT WORKSPACE

npm workspace for pi coding agent extensions. TypeScript, ESM-only.

Files here are the source of truth; `install.sh` symlinks them into `~/.pi/`.

## Structure

```
dotfiles/pi/
├── package.json                # Workspace root (workspaces = ["agent/extensions/*"])
├── tsconfig.json               # Strict, bundler mode, ESNext, noEmit
├── AGENTS.md                   # This file
├── settings.base.json          # Merged with settings.local.json into ~/.pi/agent/settings.json
├── mcp.base.json               # Merged with mcp.local.json into ~/.pi/agent/mcp.json
└── agent/
    ├── cloak.json              # Secret masking patterns for agent output
    ├── themes/                 # Custom themes (e.g. catppuccin-macchiato)
    └── extensions/
        ├── answer.ts                       # /answer + Ctrl+. — extract questions to a form
        ├── continue-after-compaction.ts    # Auto-resume work after /compact
        ├── git-interceptor.ts              # Force non-interactive git, block --no-verify
        ├── worker-configuration-guard.ts   # Block manual edits to worker-configuration.d.ts
        ├── web-tools/                      # webfetch + websearch tools (workspace pkg)
        └── pi-skill-toggle/                # Skill discovery + toggle UI (workspace pkg)
```

## Working here

```bash
cd ~/.pi
npm install               # Install workspace deps
npm run check             # Typecheck + test each workspace package
```

After changing extension code, reload pi with `/reload`.

## Conventions

- Package-style extensions: own `package.json`, register via `pi.extensions[]`
- Standalone extensions: single `.ts` file, auto-discovered from `agent/extensions/*.ts`
- ESM only: `"type": "module"` everywhere
- Deps come from `@earendil-works/pi-{ai,coding-agent,tui}` — hoisted at the workspace root

## Adding a new extension

- Drop a single `.ts` file into `agent/extensions/` for simple hooks
- Create a directory with `package.json` for anything with dependencies; add it to `workspaces[]` in the root `package.json`
- Reload pi with `/reload`

## Related dotfiles files

- `scripts/sync-pi-config.sh` — merges base + local JSON into `~/.pi/agent/{settings,mcp}.json`
- `install.sh` — symlinks this tree into `~/.pi/`
