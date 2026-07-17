# Lessons

_Durable, append-only repo lessons — build quirks, testing tricks, gotchas.
Captured at milestone end, surfaced at plan time. Capped at 50 lines._

<!-- One lesson per bullet; keep each tight. -->
- 2026-07-17 (M01): DESIGN.md principles must be written `- IPn: text`, not `- **IPn — text**` — cairn_validate/cairn_impact only parse the colon form (the /design-interview output needed reformatting).
- 2026-07-17 (M01): In shell smoke tests, capture output to a var before grepping; `cmd | grep -q` under `set -o pipefail` can false-fail when grep exits early (SIGPIPE on cmd).
- 2026-07-17 (M01): bspm is exercised via `install.packages()` interception (pulls the r-cran-* apt binary), not a `bspm::install()` function.
