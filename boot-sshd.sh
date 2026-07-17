#!/usr/bin/env bash
# Boot script for r2u-ssh: install the runtime-supplied authorized key,
# prepare the SSH and Positron directories, then exec sshd.
set -euo pipefail

USER_NAME="rocker"
HOME_DIR="$(getent passwd "$USER_NAME" | cut -d: -f6)"
if [[ -z "${HOME_DIR:-}" || ! -d "$HOME_DIR" ]]; then
  echo "ERROR: cannot resolve home directory for user '$USER_NAME'." >&2
  exit 1
fi

install -d -m 755 -o "$USER_NAME" -g "$USER_NAME" "$HOME_DIR"
install -d -m 700 -o "$USER_NAME" -g "$USER_NAME" "$HOME_DIR/.ssh"
install -d -m 755 -o "$USER_NAME" -g "$USER_NAME" "$HOME_DIR/.positron-server"

KEYDST="$HOME_DIR/.ssh/authorized_keys"

# Fail closed: an authorized key must be supplied at runtime, via either a
# mounted /keys/authorized_keys (wins) or the AUTHORIZED_KEYS_B64 env var.
# Strip any CR (CRLF/BOM contamination from Windows-authored .env files) so a
# stray "\r" never silently breaks key matching.
if [[ -f /keys/authorized_keys ]]; then
  tr -d '\r' < /keys/authorized_keys > "$KEYDST"
elif [[ -n "${AUTHORIZED_KEYS_B64:-}" ]]; then
  printf '%s' "$AUTHORIZED_KEYS_B64" | base64 -d | tr -d '\r' > "$KEYDST"
else
  echo "ERROR: no authorized key provided." >&2
  echo "       mount /keys/authorized_keys or set AUTHORIZED_KEYS_B64." >&2
  exit 1
fi

# A present-but-empty key (e.g. malformed base64 that decoded to nothing) is
# still a misconfiguration: fail closed rather than start sshd with no key.
if [[ ! -s "$KEYDST" ]]; then
  echo "ERROR: the provided authorized key is empty after decoding." >&2
  exit 1
fi

# Guarantee exactly one trailing newline (strip trailing blank lines, add one).
printf '%s\n' "$(cat "$KEYDST")" > "$KEYDST"

chown -R "$USER_NAME:$USER_NAME" "$HOME_DIR/.ssh" "$HOME_DIR/.positron-server"
chmod 700 "$HOME_DIR/.ssh"
chmod 600 "$KEYDST"

echo "Starting sshd..."
exec /usr/sbin/sshd -D -e
