# Bitcoin Core Container Image

A containerized deployment of [Bitcoin Core](https://bitcoincore.org/). This image is built with a multi-stage Docker compilation pipeline, cryptographically verifies upstream binaries, and enforces a hardened, unprivileged runtime environment.

## Architecture & Security Highlights

* **Unprivileged Execution:** The container runs strictly as the non-root `bitcoin` system user (`UID 10001`, `GID 10001`).
* **Cryptographic Verification:** During the image build phase, the system automatically pulls upstream binaries, matches SHA256 checksums, imports Guix builder keys, and cryptographically verifies the signatures (`SHA256SUMS.asc`) using GPG.
* **Volume Isolation:** Blockchain data is persisted inside a dedicated Docker named volume (`bitcoin_data_dir`), isolating state from the host operating system.

---

## Directory Layout & Key Files

* `Dockerfile`: Multi-stage build process. Evaluates `TARGETARCH` during compilation to dynamically fetch `x86_64` or `aarch64` binaries.
* `version.txt`: Manages current tag version matching the `upver` standard.
* `upver.yaml`: Declarative config linking `version.txt` and the `Dockerfile` parameter `CORE_VERSION`.
* `Makefile`: Task orchestrator for building, launching, and managing the runtime stack.

---

## Port Mappings

| Container Port | Host Port | Purpose |
|:---|:---|:---|
| `8332` | `8332` | JSON-RPC Interface (secured via `.cookie` file) |
| `8333` | `8333` | Bitcoin Peer-to-Peer network communication |

---

## Volume Mounts

* `bitcoin_data_dir` mapped to `/home/bitcoin/.bitcoin` (Contains the raw blocks, UTXO set, and the auto-generated `.cookie` credentials).

---

## Operational Guide

Run these commands inside the `image-core` directory.

### Build the Image
```bash
# Build matching the host machine architecture
make build

# Build and push cross-platform images (amd64/arm64) to your registry
make build-multiarch