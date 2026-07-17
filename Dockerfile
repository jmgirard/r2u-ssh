# ============================================================
# Dockerfile: rocker-r2u with SSH server for Positron
# ============================================================

# ------------------------------------------------------------
# 1. Load base image and define metadata labels
# ------------------------------------------------------------

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
# 2. Create non-root user (rocker)
# ------------------------------------------------------------

RUN useradd -m -s /bin/bash rocker \
    && install -d -m 700 -o rocker -g rocker /home/rocker/.ssh

# ------------------------------------------------------------
# 3. Install OpenSSH server
# ------------------------------------------------------------

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openssh-server curl wget ca-certificates tar gzip xz-utils \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd

# ------------------------------------------------------------
# 4. Configure sshd (key-only authentication)
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
    "AllowUsers rocker" \
    "AuthorizedKeysFile .ssh/authorized_keys" \
    > /etc/ssh/sshd_config.d/zz-container.conf

# ------------------------------------------------------------
# 5. Boot script: installs the key, prepares dirs, runs sshd
# ------------------------------------------------------------

COPY --chmod=0755 boot-sshd.sh /usr/local/bin/boot-sshd.sh

# ------------------------------------------------------------
# 6. Set up bspm and permissions
# ------------------------------------------------------------

# Install sudo
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends sudo \
    && rm -rf /var/lib/apt/lists/*

# Allow passwordless sudo for the SSH user
RUN usermod -aG sudo rocker \
    && printf "%s\n" "rocker ALL=(ALL) NOPASSWD: ALL" \
        > /etc/sudoers.d/90-bspm \
    && chmod 440 /etc/sudoers.d/90-bspm

# Enable bspm and use sudo backend inside R
RUN sed -i '/suppressMessages(bspm::enable())/i options(bspm.sudo = TRUE)' \
    /etc/R/Rprofile.site

# Ensure SSH user owns its home so Positron can install the remote server
RUN mkdir -p /home/rocker \
    && chown -R rocker:rocker /home/rocker

# ------------------------------------------------------------
# Expose SSH port and set default command
# ------------------------------------------------------------

EXPOSE 22
CMD ["/usr/local/bin/boot-sshd.sh"]
