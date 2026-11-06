# M04: CI build workflow

**Status:** done (2026-11-05, PR #4 https://github.com/jmgirard/r2u-ssh/pull/4)

**Goal:** Run lint, an amd64 image build, and the smoke test on GitHub Actions for every pull request into main and every push to main that changes files outside `cairn/`.

**Outcome:** New `.github/workflows/ci.yml`: triggers on PRs into main, pushes to main
(`paths-ignore: cairn/**`), and `workflow_dispatch`; one `ubuntu-24.04` job
`build-and-smoke` (45-minute timeout, PR runs cancel superseded ones, checkout
without persisted credentials) runs hadolint v2.15.1 and shellcheck v0.11.0
from Docker images, then `test/smoke.sh`. Pushes no images. `.github` added to
`.dockerignore`. DESIGN Known issue "Platform-biased testing" now names CI's
amd64 coverage, its dependence on the r2u mirror, and that arm64 and Windows
stay manual. The first GitHub run passed 12 of 12 smoke checks in 1m16s.

**Decisions:** CI is test-only; the release push stays the manual handoff of
D-001 (M02's "No GitHub Actions" was about publishing). arm64 job and branch
protection declined at the plan question set.

**Review:** four-lens fan-out, 15 findings: 6 fixed (timeout, no persisted
token, PR concurrency, mirror note in DESIGN, DESIGN wording, Decisions
entry), 2 absorbed into the new row "Keep upstream flakes from failing CI"
(normal; it also holds the r2u mirror concern from branch
`diag/mirror-arch-probe`), 6 rejected, prior-review none. Graduated the "CI
build workflow" candidate row; lesson captured (actionlint); M03 lint lesson used.
