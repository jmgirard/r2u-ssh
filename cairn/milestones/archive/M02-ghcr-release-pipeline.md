# M02: GHCR release pipeline (done 2026-07-17)

**Goal:** Make D-001's GHCR convenience image real and release-ready — honest 0.x
version, one GHCR name everywhere, base-digest provenance, verified multi-arch
build, dual-channel docs.

**Outcome:** PR #2 (squash `abbe712`). OCI version `1.0.0`→`0.1.0` (GP3); added
`base.name` + `base.digest` provenance labels (`ARG BASE_DIGEST`, empty on local
builds). Image named `ghcr.io/jmgirard/r2u-ssh` in compose + docs. README gained
an "Alternative: use the prebuilt image" note (pull vs `--build`; clone+build
stays fresher, GP4/GP6). PROFILE release-walk now resolves + records the base
digest and pushes multi-arch `:v0.1.0` + `:latest` via one `buildx build --push`.
No GitHub Actions — push stays a manual handoff (D-001).

**Evidence:** version=0.1.0 + base.* labels via `docker inspect`; buildx
amd64+arm64 exit 0; hadolint clean; smoke 11/11 (2 new label assertions);
`cairn_validate` all pass.

**Key decisions:** AC1 narrowed via review-gate amendment ("no live 1.0.0 label
/ stale claim"; historical refs OK). BASE_DIGEST ruled non-secret provenance
(not an IP2 violation).

**Review:** 3 fresh-context reviewers + scorer. F1 (release-walk handoff missing
buildx builder + `docker login ghcr.io` prereqs; scored 85) fixed. Blame-history
and prior-PR reviewers: no findings. Merged on user approval.
