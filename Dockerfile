# ============================================================
# Dockerfile: rocker-r2u with SSH server for Positron
# ============================================================

FROM rocker/r2u:24.04

LABEL org.opencontainers.image.title="r2u-ssh"
LABEL org.opencontainers.image.description="r2u environment with SSH access"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.url="https://github.com/jmgirard/r2u-ssh"
LABEL org.opencontainers.image.documentation="https://github.com/jmgirard/r2u-ssh/blob/main/README.md"
LABEL org.opencontainers.image.source="https://github.com/jmgirard/r2u-ssh"
LABEL org.opencontainers.image.vendor="Jeffrey M. Girard"
LABEL org.opencontainers.image.authors="Jeffrey M. Girard <jeffrey.m.girard@ku.edu>"
LABEL org.opencontainers.image.licenses="MIT"

# ------------------------------------------------------------
# 1. Create non-root user (rocker)
# ------------------------------------------------------------

ARG USERNAME=rocker

RUN useradd -m -s /bin/bash ${USERNAME} \
    && install -d -m 700 -o ${USERNAME} -g ${USERNAME} /home/${USERNAME}/.ssh

# ------------------------------------------------------------
# 2. Install OpenSSH server
# ------------------------------------------------------------

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openssh-server curl wget ca-certificates tar gzip xz-utils \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd

# ------------------------------------------------------------
# 3. Configure sshd (key-only authentication)
# ------------------------------------------------------------

RUN printf "%s\n" \
    "Port 22" \
    "Protocol 2" \
    "PermitRootLogin no" \
    "PasswordAuthentication no" \
    "KbdInteractiveAuthentication no" \
    "ChallengeResponseAuthentication no" \
    "PubkeyAuthentication yes" \
    "UsePAM yes" \
    "AllowUsers ${USERNAME}" \
    "AuthorizedKeysFile .ssh/authorized_keys" \
    > /etc/ssh/sshd_config.d/zz-container.conf

# ------------------------------------------------------------
# 4. Boot script: sets up keys, permissions, and runs sshd
# ------------------------------------------------------------

RUN printf '%s\n' \ 
    '#!/usr/bin/env bash' \ 
    'set -euo pipefail' \ 
    'USER="${USERNAME:-rocker}"' \ 
    'HOME_DIR="$(getent passwd "$USER" | cut -d: -f6)"' \ 
    'if [[ -z "${HOME_DIR:-}" || ! -d "$HOME_DIR" ]]; then' \ 
    ' echo "ERROR: Cannot resolve home for user $USER"; exit 1;' \ 
    'fi' \ 
    'install -d -m 755 -o "$USER" -g "$USER" "$HOME_DIR"' \ 
    'install -d -m 700 -o "$USER" -g "$USER" "$HOME_DIR/.ssh"' \ 
    'install -d -m 755 -o "$USER" -g "$USER" "$HOME_DIR/.positron-server"' \ 
    'KEYDST="$HOME_DIR/.ssh/authorized_keys"' \ 
    'if [[ -f /keys/authorized_keys ]]; then' \ 
    ' cp /keys/authorized_keys "$KEYDST"' \ 
    'elif [[ -n "${AUTHORIZED_KEYS_B64:-}" ]]; then' \ 
    ' echo "$AUTHORIZED_KEYS_B64" | base64 -d > "$KEYDST"' \ 
    'else' \ 
    ' echo "Warning: No authorized_keys provided; SSH may refuse connections."' \ 
    'fi' \ 
    'chown -R "$USER:$USER" "$HOME_DIR/.ssh" "$HOME_DIR/.positron-server" || true' \ 
    'chmod 700 "$HOME_DIR/.ssh"' \ 
    'if [[ -f "$KEYDST" ]]; then chmod 600 "$KEYDST"; fi' \ 
    'echo "Starting sshd..."' \ 
    'exec /usr/sbin/sshd -D -e' \ 
    > /usr/local/bin/boot-sshd.sh \ 
    && chmod +x /usr/local/bin/boot-sshd.sh

# ------------------------------------------------------------
# 5. Set up bspm and permissions
# ------------------------------------------------------------

# Install sudo 
RUN apt-get update \ 
    && apt-get install -y --no-install-recommends sudo \ 
    && rm -rf /var/lib/apt/lists/* 

# Allow passwordless sudo for the SSH user 
RUN usermod -aG sudo "$USERNAME" \ 
    && printf "%s\n" "$USERNAME ALL=(ALL) NOPASSWD: ALL" \ 
        > /etc/sudoers.d/90-bspm \ 
    && chmod 440 /etc/sudoers.d/90-bspm 

# Enable bspm and use sudo backend inside R 
RUN sed -i '/suppressMessages(bspm::enable())/i options(bspm.sudo = TRUE)' \ 
    /etc/R/Rprofile.site 
    
# Ensure SSH user owns its home so Positron can install the remote server 
RUN mkdir -p /home/${USERNAME} \ 
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

# ------------------------------------------------------------
# 6. Expose SSH port and set default command
# ------------------------------------------------------------

EXPOSE 22
CMD ["/usr/local/bin/boot-sshd.sh"]
