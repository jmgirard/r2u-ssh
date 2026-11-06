# Changelog

All notable user-visible changes to this image are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/); while the image is
pre-1.0 its runtime interface may change between releases.

## [Unreleased]

### Added

- A prebuilt multi-architecture image (`linux/amd64` + `linux/arm64`) is now
  published to the GitHub Container Registry as a convenience; the README shows
  how to pull it instead of building. Building locally stays the fresher path.
- Base-image provenance labels (`org.opencontainers.image.base.name` and
  `.base.digest`) so a pulled image records which `rocker/r2u:24.04` digest it
  was built from.
- `git` is now installed in the image, so the `rocker` user can run it over
  SSH (the connection Positron uses) without installing it first. No git
  identity is preset: set your own `user.name` and `user.email` with
  `git config --global` before you commit.
- `less` is now installed, so git output now pages through `less` (git's
  default pager) instead of `more`. The image presets no pager settings.

### Changed

- Files in the container's home folder (`/home/rocker`) now survive
  `docker compose down`, because `docker-compose.yml` keeps the whole home
  folder in a named volume called `home`. `docker compose down -v` deletes that
  volume and the files in it. R packages installed as Ubuntu binaries (through
  bspm or apt) are not in the home folder. They are not kept, so you must
  install them again.
- The first `docker compose up` after you update starts a new container on a
  new home volume, so files in the old container are lost. Copy out any files
  you want to keep before you update.
- The `positron_cache` volume is no longer used, because the Positron server
  folder is now in the home volume. Find the old volume with `docker volume ls`.
  Its name is `<folder>_positron_cache`, where `<folder>` is the name of your
  clone folder. Remove it with `docker volume rm <folder>_positron_cache`.
- The image version label now reads `0.1.0` instead of `1.0.0`, honestly
  reflecting that the runtime interface is still pre-1.0 and may change.
- The authorized SSH key is now sanitized at boot — carriage returns from
  CRLF/BOM-contaminated `.env` files are stripped and a single trailing newline
  is guaranteed — so a Windows-authored key no longer fails silently.
- The README `.env` recipes strip surrounding whitespace before encoding the key.

### Removed

- The `USERNAME` setting. The SSH user is always `rocker`: the build no longer
  accepts a `USERNAME` build argument and the `.env` recipes no longer write a
  `USERNAME` line (it never took effect).

### Fixed

- The container now fails fast at startup with a clear error when no authorized
  key is provided, instead of starting `sshd` anyway and failing confusingly on
  connection later.
