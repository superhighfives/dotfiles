# Oxlint + anti-slop migration plan

Plan for trying [oxlint](https://oxc.rs) and adopting [anti-slop](https://github.com/dmmulroy/anti-slop) across projects.

## Background

anti-slop is a set of 15 opinionated oxlint rules that reject "low-evidence"
TypeScript patterns - `unknown` params/returns, chained `as` assertions,
`Record<string, unknown>` dictionaries, runtime `typeof` narrowing, and
un-commented type assertions. It targets the kind of code LLMs tend to emit.

Two things to keep in mind:

- It's meant to be **vendored, not installed as a dependency**. You copy `src/`
  into the repo and own it from there.
- It **only works with oxlint** - there's no ESLint version. So adopting
  anti-slop means adopting oxlint, at least for these rules.

## Migration path

Oxlint is designed to sit alongside ESLint, so this can be tried with no risk to
the existing setup.

- Install oxlint: `npm install -D oxlint`
- Run once with no config to gauge noise: `npx oxlint`
- Migrate the existing ESLint config: `npx @oxlint/migrate` (flags rules it can't
  map - usually the type-aware ones)
- Run oxlint *before* ESLint rather than instead of it:
  `"lint": "oxlint && eslint ."`
- Add `eslint-plugin-oxlint` last in the ESLint config to disable the rules
  oxlint already covers, avoiding double-reporting
- Wire up the editor (`oxc.oxc-vscode`) and add the `oxlint` step ahead of ESLint
  in CI
- Decide whether ESLint can be dropped entirely (see caveat below)

## The one caveat: type-aware rules

Oxlint is fast because it doesn't do full type-checking, so rules that need type
information aren't fully there yet:

- `no-floating-promises`
- `no-misused-promises`
- `no-unsafe-*`
- `await-thenable`

If a project leans on these, keep ESLint + typescript-eslint for that slice and
let oxlint handle the rest. If not, ESLint can likely go entirely.

## Adopting anti-slop

Once oxlint is in place:

- Vendor `src/` into the repo (e.g. `tools/oxlint/anti-slop/`) rather than using
  the skill install blindly - the rules are yours to edit
- Register the plugin in `oxlint.config.ts` via `jsPlugins` + the rules block
  from the README
- Read each rule and disable what doesn't fit. Some are aggressive and will fight
  legitimate code: `no-runtime-typeof`, `no-object-parameters`,
  `no-unknown-parameters`

## Formatting (oxfmt) - hold off for now

Keep this separate from the linting decision. oxfmt is much newer and less mature
than oxlint. Prettier and Biome are both more battle-tested. anti-slop does not
require oxfmt.

## Recommendation

- Try anti-slop's rules alongside the existing ESLint setup first - oxlint is
  fast enough that running both isn't painful
- Vendor anti-slop, don't skill-install it blindly
- Keep formatting on Prettier or Biome unless specifically testing oxfmt
