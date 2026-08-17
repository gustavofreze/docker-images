---
description: Structure, naming, quoting, control flow, and logging rules for the Bash scripts in this repository, both the host-side tooling under scripts/ and the assets baked into an image under a build unit's bin/ and scripts/.
paths:
    - "*.sh"
    - "**/*.sh"
    - "scripts/**"
    - "**/scripts/**"
    - "**/bin/**"
---

# Scripts

Semantic rules for the Bash in this repository. Two kinds of script live here and both follow this
rule:

- **Host-side tooling** under `scripts/`, run by the Makefile and by the CI workflows
  (`discover-images.sh`, `smoke-lib.sh`).
- **Build unit assets** under `images/<family>/<minor>/`, either baked into an image from `bin/` or
  run on the host against a built image from `scripts/` (`scripts/smoke`, `bin/phpmd`).

Bash inside a Dockerfile `RUN` body is covered too. ShellCheck runs on every `RUN` through hadolint
in the lint stage of the gate, so a violation there fails `make lint`.

### Carve-out: sourced libraries

A file that is only ever sourced, never executed, is exempt from the `set -euo pipefail` and `main()`
rules: the sourcing script owns both, and setting them in a library would leak shell options into
every caller. `scripts/smoke-lib.sh` is the one such file today. It still carries the shebang (as
documentation of its dialect), a header comment block, and a `# shellcheck shell=bash` directive so
ShellCheck knows what it is reading. Everything else in this rule still applies to it.

## Pre-output checklist

Verify every item before producing any Bash script.

1. Shebang is `#!/usr/bin/env bash`. See § Carve-out for sourced libraries.
2. `set -euo pipefail` is the first line after the shebang. Sourced libraries are exempt.
3. A header comment block follows, with name, one-line description, usage, and arguments.
4. A `main()` function exists. Top-level code is limited to sourcing libraries, `readonly` constants,
   and `main "$@"`. Sourced libraries are exempt.
5. `main "$@"` is the last line of the file.
6. The shared smoke library is sourced through the exported path
   (`source "${SMOKE_LIB:?SMOKE_LIB not set}"`), never a relative path, so it resolves the same from
   the Makefile and from a workflow.
7. Arguments are validated early with guard clauses (`local x="${1:?Usage: ...}"`).
8. All variables are double-quoted: `"${variable}"`, `"$@"`.
9. Conditionals use `[[ ]]`, never `[ ]` or `test`.
10. Command substitution uses `$(command)`, never backticks.
11. No `else` or `elif`. Use guard clauses with early exit.
12. `case` is used over chained `if` for multiple conditions.
13. `cd` is always paired with `|| exit 1`.
14. Cleanup logic uses `trap` on `EXIT`.
15. Constants are declared with `readonly` and ordered by name length ascending.
16. Functions are ordered: helpers first, then their callers, `main` last.
17. No abbreviations in identifiers.
18. American English in all identifiers, comments, and documentation.

## Files

- Executable scripts invoked as a command use **no extension** (`smoke`, `phpmd`).
- Library scripts sourced into other scripts use the **`.sh` extension** (`smoke-lib.sh`).
- Host-side tooling invoked by file path from the Makefile or a workflow keeps its `.sh` extension
  (`discover-images.sh`).
- File names use `kebab-case`.
- A script baked into an image is copied with `COPY --chmod=755` to `/usr/local/bin/<name>`, so the
  executable bit is set in the layer and never assumed from the host checkout.

## Naming

- Functions: `snake_case`, descriptive verbs (`read_targets`, `build_entries`).
- Local variables: `snake_case`, declared with `local`.
- Constants and exported variables: `SCREAMING_SNAKE_CASE`.

## Logging

- Informational output goes to `stderr` (`>&2`) and only machine-readable output goes to `stdout`.
  This is not cosmetic here: `discover-images.sh --format=json` is captured straight into a workflow
  output, and a stray `echo` on stdout corrupts the build matrix.
- A bracketed prefix identifies the source (`echo "[smoke] ok: ..."`). The smoke scripts get theirs
  from the shared library rather than repeating the idiom.

## Comments

Explain a non-obvious choice, never restate the line below. The header block is required, the
narration of an obvious `for` loop is not. Where a decision spans more than one file (an ordering
constraint, an accepted exemption), the reasoning belongs in the `docker-images` rule and the script
carries at most a pointer.

## Size

A script here stays a script. Past roughly 150 lines, or once it needs real data structures, state
machines, or retry logic, that is the signal to reconsider the approach rather than keep growing the
file: move the logic into the Makefile, split it, or drop the feature. This repository ships no
compiler and no runtime beyond Docker and GNU Make, so a rewrite in another language is not a
shortcut available here.
