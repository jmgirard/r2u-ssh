# M04: CI build workflow

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP3
- **Resolves:** —
- **Surface tier:** internal — CI tooling that only the maintainer's merge process reads
- **Branch/PR:** m004-ci-workflow

## Goal

Run lint, an amd64 image build, and the smoke test on GitHub Actions for every pull request into main and every push to main that changes files outside `cairn/`.

## Scope

**In:** a new `.github/workflows/ci.yml` with one job on `ubuntu-24.04`: checkout, hadolint
on `Dockerfile` and shellcheck on `boot-sshd.sh` and `test/smoke.sh` (both from the pinned
Docker images the repo already uses locally), then `test/smoke.sh`, which builds the image and
runs every check. Triggers: `pull_request` into main, `push` to main with `cairn/**` ignored,
and `workflow_dispatch`. The "Platform-biased testing" Known issue in `cairn/DESIGN.md` is
updated to say what CI now covers.

**Out:** an arm64 CI job (declined at the plan question set, 2026-11-05). Branch protection or
any other repo-settings change (declined at the plan question set, 2026-11-05). Image
publishing and scheduled rebuilds (D-001 keeps the GHCR push a manual handoff and declined
scheduled rebuilds; this workflow pushes nothing). A vulnerability scan (the profile calls it
optional; not requested).

## Acceptance criteria

- [x] AC1: `.github/workflows/ci.yml` triggers on `push` to `main` with `paths-ignore: ['cairn/**']`, on `pull_request` targeting `main`, and on `workflow_dispatch`, as read from the file.
- [x] AC2: The workflow has one job on `ubuntu-24.04`; after checkout, its steps run in this order: hadolint on `Dockerfile` from the `hadolint/hadolint:v2.15.1` image, shellcheck on `boot-sshd.sh` and `test/smoke.sh` from the `koalaman/shellcheck:v0.11.0` image, and `test/smoke.sh`, as read from the file.
- [x] AC3: actionlint, run from the `rhysd/actionlint` Docker image at a pinned version, reports no errors on `.github/workflows/ci.yml`.
- [x] AC4: The workflow contains no `continue-on-error` key and no `||` operator in any `run:` block, as shown by `grep -nE 'continue-on-error|\|\|' .github/workflows/ci.yml` finding no match.
- [x] AC5: Run locally as the workflow spells them, with only the input path changed, the hadolint and shellcheck commands exit 0 on the branch's files and exit non-zero on a temporary copy carrying one planted violation each; `test/smoke.sh` passes locally with 12 of 12 checks.
- [x] AC6: The "Platform-biased testing" entry in `cairn/DESIGN.md` Known issues says the amd64 build and smoke test now run in CI on every pull request into main and every push to main that changes files outside `cairn/`, and that arm64 and Windows PowerShell stay manual.

## Coverage

- AC1 → T1
- AC2 → T1
- AC3 → T2
- AC4 → T1, T2
- AC5 → T2
- AC6 → T3

## Tasks

- [x] T1: Write `.github/workflows/ci.yml`: the three triggers, one `ubuntu-24.04` job,
      `actions/checkout` at a pinned major tag, then the hadolint, shellcheck, and smoke steps
      with the commands from LESSONS (hadolint reads `Dockerfile` on stdin; shellcheck mounts
      the repo read-only). No `continue-on-error` and no `||` in any `run:` block.
- [x] T2: Run actionlint from Docker on the workflow, the AC4 grep, the hadolint and shellcheck
      commands on the real files and on temp copies with one planted violation each (record
      each exit code), and `test/smoke.sh` locally.
- [x] T3: Update the "Platform-biased testing" entry in `cairn/DESIGN.md` Known issues.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: not run — work named at the question set.
- 2026-11-05: idea vet: no flaw; gap: trigger set — read as PR into main plus push to main with `cairn/**` ignored, so branch checkpoint pushes start no run and the first run is on the PR head (D-138 pattern).
- 2026-11-05: lessons used: 2026-11-05 (M03) hadolint and shellcheck from Docker images.
- 2026-11-05: question set: what CI runs — lint, amd64 build, and full smoke; no arm64 job.
- 2026-11-05: question set: branch protection — leave repo settings unchanged.
- 2026-11-05: collision: candidate row "CI build workflow" absorbed; D-001 declined scheduled rebuilds and self-pushing, and this workflow is neither (no schedule, no push of images).
- 2026-11-05: inbox sweep: 0 open issues, 0 open PRs.
- 2026-11-05: plan gate chose running test/smoke.sh in CI over lint and build only because only smoke exercises SSH, bspm, and git on amd64; falsified by smoke runs that fail on GitHub runners for reasons unrelated to the image.
- 2026-11-05: criteria audit (reduced mode): 5 findings, all fixed — Goal/AC6 now say pushes touching only `cairn/` are skipped; AC4 narrowed to no `continue-on-error` key and no `||` in `run:` blocks; AC5 says only the input path changes; AC2 says steps follow checkout; no criterion claims a green GitHub run before review, because the PR (and its first CI run) opens after merge approval and the merge step refuses red or pending CI.

- 2026-11-05: implement started on m004-ci-workflow; the unrelated local `.DS_Store` change stays unstaged (M05 handles it).
- 2026-11-05: T1 done: `.github/workflows/ci.yml` with `actions/checkout@v7` (latest release v7.0.1), `permissions: contents: read`, and one job `build-and-smoke`; added `.github` to `.dockerignore` so the new directory stays out of the build context (minor amendment).
- 2026-11-05: T2 done: actionlint 1.7.12 exit 0 on ci.yml (a planted undefined-property workflow exits 1); masking grep exit 1 (no match); hadolint exit 0 on Dockerfile, exit 1 on a copy with `RUN cd /tmp` (DL3003, line 101); shellcheck exit 0 on both scripts, exit 1 on a boot-sshd.sh copy with `ls $HOME_DIR` (SC2086, line 49); local smoke 12 passed, 0 failed.
- 2026-11-05: T3 done: DESIGN Known issues "Platform-biased testing" names CI's amd64 coverage and says arm64 and Windows PowerShell stay manual.
- 2026-11-05: claim audit: not owed — internal tier.
- 2026-11-05: implement done; status review.

## Decisions

- 2026-11-05: GitHub Actions now runs a test-only workflow. It builds and tests the image and pushes nothing, so the release push stays the manual handoff that D-001 and M02's "No GitHub Actions" stance describe; that stance was about publishing, not testing. The user chose this CI at the plan question set.

## Review

Evidence (2026-11-05, branch head 8c2a83a, synced with origin/main 7768521):

- AC1: ci.yml lines 3-10: `push` with `branches: [main]` and `paths-ignore: ['cairn/**']`, `pull_request` with `branches: [main]`, `workflow_dispatch`.
- AC2: one job `build-and-smoke`, `runs-on: ubuntu-24.04`; after `actions/checkout@v7`, steps are hadolint (`hadolint/hadolint:v2.15.1` < Dockerfile), shellcheck (`koalaman/shellcheck:v0.11.0` on /mnt/boot-sshd.sh /mnt/test/smoke.sh), then `test/smoke.sh`, in that order.
- AC3: `rhysd/actionlint:1.7.12` on ci.yml: exit 0, no output.
- AC4: `grep -nE 'continue-on-error|\|\|' .github/workflows/ci.yml`: exit 1, no match.
- AC5: hadolint on Dockerfile exit 0; on the planted copy (`RUN cd /tmp`) exit 1 with DL3003. shellcheck on both scripts exit 0; on the planted boot-sshd.sh copy (`ls $HOME_DIR`) exit 1 with SC2086. Only the input path changed. Local `test/smoke.sh`: 12 passed, 0 failed.
- AC6: DESIGN.md Known issues "Platform-biased testing" now says CI lints, builds, and runs `test/smoke.sh` on amd64 for every pull request into main and every push to main that changes files outside `cairn/`, and that arm64 and the Windows PowerShell path stay manual.
- Gate: `cairn_validate` all checks passed (1 advisory: `.gitignore` pdf entry, pre-existing). No principle changed, so `cairn_impact` skipped. Profile gate: `docker build` succeeded (inside smoke); hadolint clean; base pinned to the explicit `rocker/r2u:24.04` tag; no secrets in ENV/COPY (grep hits are comments only); `.dockerignore` present and now also excludes `.github`; no CHANGELOG entry owed, since users of the image see no change.

Findings (spawned: diff-bug, blame-history, prior-review, ripple):

- blame-history #1: smoke's bspm install and the build's apt fetches use the r2u mirror, which branch `diag/mirror-arch-probe` (2026-07-23, r2u discussion #159) recorded as unreachable for about half of GitHub-hosted runner jobs, so CI can go red for reasons unrelated to the image — fix now (DESIGN names the dependency) plus follow-up: candidate row "Keep upstream flakes from failing CI" (normal: a red run blocks the merge step).
- blame-history #2: DESIGN's new amd64-coverage text omits that dependency — fix now.
- blame-history #3: no record for adding GitHub Actions after M02's "No GitHub Actions" push stance — fix now (milestone Decisions entry).
- diff-bug #1: no `timeout-minutes`, so a hung network step holds the job for 360 minutes — fix now.
- diff-bug #2: anonymous Docker Hub pulls of three images can hit rate limits — follow-up: absorbed into "Keep upstream flakes from failing CI".
- diff-bug #3: smoke's `free_port` releases the port before `docker run -p` takes it — follow-up: absorbed into "Keep upstream flakes from failing CI" (pre-existing smoke code, unmodified line).
- diff-bug #4: `actions/checkout` keeps the token in `.git/config` — fix now (`persist-credentials: false`).
- diff-bug #5: no `concurrency` group, so superseded PR runs keep going — fix now (cancel in progress for pull requests only).
- diff-bug #6: a merge triggers a second run on the push to main — reject, planned change (AC1 names the push trigger, which tests main itself).
- diff-bug #7: hadolint's default threshold lets style-level findings pass — reject, planned change (CI runs the profile's local verify command as LESSONS spells it, same threshold).
- diff-bug #8: smoke discards `docker build` stdout — reject, false (BuildKit writes progress and errors to stderr, so they reach the CI log; unmodified line).
- diff-bug #9: DESIGN does not mention `workflow_dispatch` — reject, style (AC6 does not call for it; the trigger is in the file).
- prior-review: no prior-review evidence on the touched files (archives hold no CI finding; PR comment probe empty).
- ripple #1: PROFILE test-doctrine says CI runs `docker build` + `hadolint` on push/PR — reject, false (the slot states the floor a CI workflow must meet, and this workflow meets it).
- ripple #2: the ROADMAP CI candidate row describes narrower scope — reject, planned change (the row graduates at post-merge hygiene).
