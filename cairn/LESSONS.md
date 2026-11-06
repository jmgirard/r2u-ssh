# Lessons

_Durable, append-only repo lessons — build quirks, testing tricks, gotchas.
Captured at milestone end, surfaced at plan time. Capped at 50 lines._

<!-- One lesson per bullet; keep each tight. -->
- 2026-07-17 (M01): DESIGN.md principles must be written `- IPn: text`, not `- **IPn — text**` — cairn_validate/cairn_impact only parse the colon form (the /design-interview output needed reformatting).
- 2026-07-17 (M01, used M03): In shell smoke tests, capture output to a var before grepping; `cmd | grep -q` under `set -o pipefail` can false-fail when grep exits early (SIGPIPE on cmd).
- 2026-11-05 (M03, used M05): No hadolint or shellcheck binary on the host; run them from Docker: `docker run --rm -i hadolint/hadolint:v2.15.1 < Dockerfile` and `docker run --rm -v "$PWD:/mnt:ro" koalaman/shellcheck:v0.11.0 /mnt/test/smoke.sh /mnt/boot-sshd.sh`.
- 2026-07-17 (M01): bspm is exercised via `install.packages()` interception (pulls the r-cran-* apt binary), not a `bspm::install()` function.
- 2026-11-05 (M04): Lint the CI workflow with actionlint from Docker: `docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.12 -no-color .github/workflows/ci.yml`; `-color` is a boolean flag, so `-color=never` exits 2 with a usage error.
- 2026-07-17 (M02): Multi-arch `docker buildx build --platform` needs a container-driver builder (`docker buildx create --use`); the default `docker`/desktop driver can't emit multi-platform output — bites both local verification and the release-walk push.
- 2026-11-05 (M05): A bare name in `.dockerignore` matches only at the context root, unlike `.gitignore`; write `**/<name>` for any depth. Prove what reaches the context with a throwaway build piped on stdin: `FROM busybox`, `COPY . /ctx`, `RUN find /ctx …`, run as `docker build -f - .`.
