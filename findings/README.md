# Findings log

Every finding from a review or a health check goes here, fixed or not. Small findings are normal. The log exists so that repeated findings become visible. Luis decides which repeated findings become a machine check.

One file per branch: `findings/<branch-name>.md`. One line per finding:

`- <date> | <source> | <severity> | <area> | <what was found> | <fixed: yes, or no and why>`

- date: `2026-11-24`
- source: `review`, `health check` or `missed by check`
- severity: `high` (wrong behaviour or data loss), `medium` (will cause trouble later), `low` (style or small clean-up)
- area: the part of the app, for example `time grid`, `menu bar`, `Google sync`

Use `missed by check` when a bug got past an earlier check. Write why the check missed it.
