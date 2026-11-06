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

- [ ] AC1: `.github/workflows/ci.yml` triggers on `push` to `main` with `paths-ignore: ['cairn/**']`, on `pull_request` targeting `main`, and on `workflow_dispatch`, as read from the file.
- [ ] AC2: The workflow has one job on `ubuntu-24.04`; after checkout, its steps run in this order: hadolint on `Dockerfile` from the `hadolint/hadolint:v2.15.1` image, shellcheck on `boot-sshd.sh` and `test/smoke.sh` from the `koalaman/shellcheck:v0.11.0` image, and `test/smoke.sh`, as read from the file.
- [ ] AC3: actionlint, run from the `rhysd/actionlint` Docker image at a pinned version, reports no errors on `.github/workflows/ci.yml`.
- [ ] AC4: The workflow contains no `continue-on-error` key and no `||` operator in any `run:` block, as shown by `grep -nE 'continue-on-error|\|\|' .github/workflows/ci.yml` finding no match.
- [ ] AC5: Run locally as the workflow spells them, with only the input path changed, the hadolint and shellcheck commands exit 0 on the branch's files and exit non-zero on a temporary copy carrying one planted violation each; `test/smoke.sh` passes locally with 12 of 12 checks.
- [ ] AC6: The "Platform-biased testing" entry in `cairn/DESIGN.md` Known issues says the amd64 build and smoke test now run in CI on every pull request into main and every push to main that changes files outside `cairn/`, and that arm64 and Windows PowerShell stay manual.

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

## Review
