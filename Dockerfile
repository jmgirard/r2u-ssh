# ============================================================
# Dockerfile: rocker-r2u with SSH server for Positron
# ============================================================

# ------------------------------------------------------------
# 1. Load base image and define metadata labels
# ------------------------------------------------------------

FROM rocker/r2u:24.04

# Base-image provenance. base.name is the moving tag we track (GP4); base.digest
# is the digest that tag resolved to at build time, passed at release build
# (empty on local/dev builds). BASE_DIGEST is public provenance, not a secret —
# it is deliberately NOT the kind of value IP2 forbids as a build arg.
ARG BASE_DIGEST=""

LABEL org.opencontainers.image.title="r2u-ssh"
LABEL org.opencontainers.image.description="r2u environment with SSH access"
LABEL org.opencontainers.image.version="0.1.0"
LABEL org.opencontainers.image.url="https://github.com/jmgirard/r2u-ssh"
LABEL org.opencontainers.image.documentation="https://github.com/jmgirard/r2u-ssh/blob/main/README.md"
LABEL org.opencontainers.image.source="https://github.com/jmgirard/r2u-ssh"
LABEL org.opencontainers.image.vendor="Jeffrey M. Girard"
LABEL org.opencontainers.image.authors="Jeffrey M. Girard <jeffrey.m.girard@ku.edu>"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.base.name="rocker/r2u:24.04"
LABEL org.opencontainers.image.base.digest="${BASE_DIGEST}"

# ------------------------------------------------------------
# 2. Create non-root user (rocker)
# ------------------------------------------------------------

# Fixed UID/GID 1002 (the value useradd picked on this base), so files kept in
# the compose `home` volume stay owned by rocker after a rebuild. If the base
# ever takes 1002 itself, the build fails here instead of shifting the UID.
RUN groupadd -g 1002 rocker \
    && useradd -m -u 1002 -g rocker -s /bin/bash rocker \
    && install -d -m 700 -o rocker -g rocker /home/rocker/.ssh

# ------------------------------------------------------------
# 3. Install OpenSSH server, Positron download tools, git, and less
# ------------------------------------------------------------

# The openssh-server install writes host keys into /etc/ssh. Delete them in
# this same RUN, so no image layer holds a private host key (IP2); boot-sshd.sh
# creates each container's own keys in /etc/ssh/host_keys at start.
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openssh-server curl wget ca-certificates tar gzip xz-utils git less \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/ssh/ssh_host_* \
    && install -d -m 700 -o root -g root /etc/ssh/host_keys \
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
    "HostKey /etc/ssh/host_keys/ssh_host_ed25519_key" \
    "HostKey /etc/ssh/host_keys/ssh_host_ecdsa_key" \
    "HostKey /etc/ssh/host_keys/ssh_host_rsa_key" \
    > /etc/ssh/sshd_config.d/zz-container.conf

# ------------------------------------------------------------
# 5. Boot script: installs the key, prepares dirs, makes host keys, runs sshd
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
