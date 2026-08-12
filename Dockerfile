# Declare once globally at the very top
ARG CORE_VERSION="31.1"

# --- Stage 1: Build & Verify (Fast execution on Build Platform) ---
FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gnupg \
    git \
    && rm -rf /var/lib/apt/lists/*

ARG CORE_VERSION

# Automatically provided by Docker Buildx during multi-platform builds
ARG TARGETARCH

WORKDIR /tmp

# Download binary, checksums, and signature mapping platforms dynamically
RUN if [ "${TARGETARCH}" = "amd64" ]; then \
        ARCH="x86_64-linux-gnu"; \
    elif [ "${TARGETARCH}" = "arm64" ]; then \
        ARCH="aarch64-linux-gnu"; \
    else \
        echo "Unsupported target architecture: ${TARGETARCH}" && exit 1; \
    fi && \
    curl -SLO https://bitcoincore.org/bin/bitcoin-core-${CORE_VERSION}/bitcoin-${CORE_VERSION}-${ARCH}.tar.gz \
    && curl -SLO https://bitcoincore.org/bin/bitcoin-core-${CORE_VERSION}/SHA256SUMS \
    && curl -SLO https://bitcoincore.org/bin/bitcoin-core-${CORE_VERSION}/SHA256SUMS.asc \
    && sha256sum --ignore-missing --check SHA256SUMS \
    && git clone https://github.com/bitcoin-core/guix.sigs.git \
    && gpg --batch --import guix.sigs/builder-keys/* \
    && gpg --batch --verify SHA256SUMS.asc SHA256SUMS \
    && tar -xzf bitcoin-${CORE_VERSION}-${ARCH}.tar.gz

# --- Stage 2: Hardened Runtime Layer ---
FROM debian:13.6-slim

ARG CORE_VERSION

# Copy only the compiled/verified binaries from stage 1
COPY --from=builder /tmp/bitcoin-${CORE_VERSION}/bin/bitcoind /usr/local/bin/bitcoind
COPY --from=builder /tmp/bitcoin-${CORE_VERSION}/bin/bitcoin-cli /usr/local/bin/bitcoin-cli

# Copy the version file for reference
COPY --chown=10001:10001 version.txt /usr/local/bin/version.txt

# Bake in your opinionated default bitcoin.conf
COPY --chown=10001:10001 bitcoin.conf /home/bitcoin/.bitcoin/bitcoin.conf

USER 10001:10001

# P2P and RPC default ports
EXPOSE 8332 8333

ENTRYPOINT ["bitcoind"]
CMD ["-printtoconsole=1"]