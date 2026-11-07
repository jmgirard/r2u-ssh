# Lessons

_Durable, append-only repo lessons — build quirks, testing tricks, gotchas.
Captured at milestone end, surfaced at plan time. Capped at 50 lines._

<!-- One lesson per bullet; keep each tight. -->
- 2026-07-17 (M01): DESIGN.md principles must be written `- IPn: text`, not `- **IPn — text**` — cairn_validate/cairn_impact only parse the colon form (the /design-interview output needed reformatting).
- 2026-07-17 (M01, used M09): In shell smoke tests, capture output to a var before grepping; `cmd | grep -q` under `set -o pipefail` can false-fail when grep exits early (SIGPIPE on cmd).
- 2026-11-05 (M03, used M09): No hadolint or shellcheck binary on the host; run them from Docker: `docker run --rm -i hadolint/hadolint:v2.15.1 < Dockerfile` and `docker run --rm -v "$PWD:/mnt:ro" koalaman/shellcheck:v0.11.0 /mnt/test/smoke.sh /mnt/boot-sshd.sh`.
- 2026-07-17 (M01): bspm is exercised via `install.packages()` interception (pulls the r-cran-* apt binary), not a `bspm::install()` function.
- 2026-11-05 (M04): Lint the CI workflow with actionlint from Docker: `docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.12 -no-color .github/workflows/ci.yml`; `-color` is a boolean flag, so `-color=never` exits 2 with a usage error.
- 2026-07-17 (M02): Multi-arch `docker buildx build --platform` needs a container-driver builder (`docker buildx create --use`); the default `docker`/desktop driver can't emit multi-platform output — bites both local verification and the release-walk push.
- 2026-11-05 (M05): A bare name in `.dockerignore` matches only at the context root, unlike `.gitignore`; write `**/<name>` for any depth. Prove what reaches the context with a throwaway build piped on stdin: `FROM busybox`, `COPY . /ctx`, `RUN find /ctx …`, run as `docker build -f - .`.
- 2026-11-05 (M06, used M09): To show a new smoke check fails without the change, copy the branch's `test/smoke.sh` into `git worktree add --detach <dir> origin/main` and run it there with another image tag; smoke.sh always builds the image from its own tree, so running it on the branch can never show the red.
- 2026-11-06 (M08, used M09): To smoke-test the real compose file without touching the user's project, run `docker compose -p <name>-$$ --project-directory <repo> -f docker-compose.yml -f <override> --env-file /dev/null` with an override setting `image:` to the smoke tag and `pull_policy: never`, then `up -d --no-build` with `SSHPORT=0`; re-read `compose port` after every `up`, since the port can change.
- 2026-11-05 (M07, used M09): `docker port <cid> 22/tcp` exits non-zero once the container has exited, so under `set -e` a fail-closed boot ends smoke.sh before any FAIL line; `host_port` reads it with `|| true`. A later `docker exec` on that container still ends the script.
- 2026-11-06 (M09): `ssh-keyscan` prints `# host:port SSH-2.0-…` banner lines on stdout, and field 1 of a key line is `[127.0.0.1]:<port>`, which differs per container; drop `#` lines and compare fields 2-3 when checking host keys across containers or recreates.
- 2026-11-06 (M09): A file deleted by a later `RUN` still ships in the lower layer, so check for secrets per layer, not in a running container: `docker save <img> | tar -xf - -C <dir>`, take the layer paths from `manifest.json` (written by both the classic and containerd stores, gzip or plain layers), and `tar -tf` each one.
