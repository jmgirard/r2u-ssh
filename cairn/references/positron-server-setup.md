# positron-server-setup — how Positron's SSH extension installs and starts its server

**Provenance.** Ingested 2026-11-06 by M10 from
`https://github.com/posit-dev/positron/blob/df65447cf817f972652b0e5526ce1bac7e073dfb/extensions/open-remote-ssh/src/serverSetup.ts`.
It was read with `gh api repos/posit-dev/positron/contents/...?ref=<commit>`. That commit was the newest one to touch the file on 2026-11-06 and is dated 2026-09-29.
Pagination: none. Anchors are line numbers in that file at that commit.
Extraction: verified 2026-11-06 against the source — observed 2026-11-06.

**Citation.** Posit Software, PBC. `extensions/open-remote-ssh/src/serverSetup.ts`, Positron repository, commit `df65447cf817f972652b0e5526ce1bac7e073dfb`. Elastic License 2.0.

**Role.** Test 16 of `test/smoke.sh` copies the steps in this file. The smoke test then installs and starts the server the way the Positron client does over SSH.

## Extracted values

- Default download URL template (line 49): `https://cdn.posit.co/positron/${quality}/reh/${arch-long}/positron-reh-${os}-${arch}-${version}.tar.gz`.
- Architecture map from `uname -m`. `x86_64 | amd64` gives arch `x64` and arch-long `x86_64` (line 402). `arm64 | aarch64` gives arch `arm64` and arch-long `arm64` (line 410).
- Install folder. `SERVER_DATA_DIR` is relative to `$HOME` (line 340). Its value is `.positron-server`, from `serverDataFolderName` in the repo's `product.json`. Then `SERVER_DIR="$SERVER_DATA_DIR/bin/$DISTRO_COMMIT"` and `SERVER_SCRIPT="$SERVER_DIR/bin/$SERVER_APP_NAME"` (lines 344-345). The app name is `positron-server`, from `product.json`.
- Download (line 478). If wget is present, the script runs `wget --tries=3 --timeout=10 --continue --no-verbose`. If not, it uses curl.
- Unpack (line 491): `tar -xf vscode-server.tar.gz --strip-components 1`.
- The token file gets mode 600 (line 530).
- Start (line 534): `$SERVER_SCRIPT --start-server --host=127.0.0.1 $SERVER_LISTEN_FLAG $SERVER_INITIAL_EXTENSIONS --connection-token-file $SERVER_TOKENFILE --server-data-dir $SERVER_DATA_DIR --telemetry-level off --enable-remote-auto-shutdown --accept-server-license-terms`. The listen flag is `--port=0` unless the client uses a socket path.
- Ready signal (line 549): the client searches the server log for `Extension host agent listening on .+`.
- For stable builds, `${quality}` is `releases`. The file does not state this value. The URL with `releases` returned HTTP 200 for `positron-reh-linux-x64-2026.11.0-308` and `positron-reh-linux-arm64-2026.11.0-308` — observed 2026-11-06.

## Traces to

- `test/smoke.sh` test 16 takes all of the values above from here.

## Open questions

- Test 16 leaves out `--enable-remote-auto-shutdown`, because the container is removed after the run. Whether the flag matters for a headless start is not known — observed 2026-11-06.
