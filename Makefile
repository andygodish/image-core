# ==============================================================================
# Bitcoin Core Custom Security Build System
# ==============================================================================

# Version Metadata Extraction
CORE_VERSION   ?= $(shell cat version.txt 2>/dev/null | cut -d- -f1 || echo "31.1")
VERSION_TAG     ?= $(shell [ -s version.txt ] && echo "v$$(cat version.txt | tr -d '\n\r ')" || echo "latest")

# Registry and Naming Coordinates
REGISTRY        := ghcr.io/andygodish
IMAGE_NAME      := bitcoin-core
FULL_TAG        := $(REGISTRY)/$(IMAGE_NAME):$(VERSION_TAG)
LATEST_TAG      := $(REGISTRY)/$(IMAGE_NAME):latest
REPO_ROOT       := $(shell pwd)

# Target Cross-Platform Architectures
PLATFORMS       ?= linux/amd64,linux/arm64

# Host Deployment Settings
CONTAINER_NAME   := bitcoin-core-node
HOST_RPC_PORT    ?= 8332
HOST_P2P_PORT    ?= 8333
VOLUME_NAME      := bitcoin_data_dir

# ==============================================================================
# Operational Targets
# ==============================================================================

.DEFAULT_GOAL := help

# Guardrail check to verify version details exist
.PHONY: verify-env
verify-env:
	@if [ ! -f version.txt ]; then \
		echo "Error: version.txt file missing in repository root."; \
		exit 1; \
	fi

# Build standard architecture matching the local host machine engine context
.PHONY: build
build: verify-env
	@echo "Building local architecture image $(IMAGE_NAME):$(VERSION_TAG)..."
	docker build \
		--build-arg CORE_VERSION=$(CORE_VERSION) \
		-t $(IMAGE_NAME):$(VERSION_TAG) \
		$(REPO_ROOT)
	@echo "Local slice build complete."

# Build and push unified multi-architecture cross-builds directly to GHCR
.PHONY: build-multiarch
build-multiarch: verify-env
	@echo "Initializing Buildx engine multi-arch compilation & push..."
	@echo "Target Registry: $(REGISTRY)"
	@echo "Platforms targeted: $(PLATFORMS)"
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg CORE_VERSION=$(CORE_VERSION) \
		-t $(FULL_TAG) \
		-t $(LATEST_TAG) \
		--push \
		$(REPO_ROOT)
	@echo "Multi-arch build successfully pushed to GHCR!"

# Orchestrated target: gracefully stops old instance, then starts the new one
.PHONY: up
up: stop run

# Spin up the node in the background using the self-contained Docker volume
.PHONY: run
run: verify-env
	@echo "Launching containerized node using native Docker named volume: $(VOLUME_NAME)..."
	docker run -d \
		--name $(CONTAINER_NAME) \
		--rm \
		-p $(HOST_RPC_PORT):8332 \
		-p $(HOST_P2P_PORT):8333 \
		-v $(VOLUME_NAME):/home/bitcoin/.bitcoin \
		$(IMAGE_NAME):$(VERSION_TAG)
	@echo "Node launched successfully on port $(HOST_RPC_PORT)."

# Gracefully stops and removes an active container or conflicting ports
.PHONY: stop
stop:
	@echo "Checking for existing container named '$(CONTAINER_NAME)'..."
	@if [ $$(docker ps -aq -f name=^/$(CONTAINER_NAME)$$ | wc -l) -gt 0 ]; then \
		echo "Found active container name. Shutting it down..."; \
		docker stop $(CONTAINER_NAME); \
	fi
	@echo "Checking for any other container squatting on ports $(HOST_RPC_PORT) or $(HOST_P2P_PORT)..."
	@CONFLICTING_CONTAINER=$$(docker ps -q -f publish=$(HOST_RPC_PORT) -f publish=$(HOST_P2P_PORT) | head -n 1); \
	if [ ! -z "$$CONFLICTING_CONTAINER" ]; then \
		echo "Found conflicting container ID $$CONFLICTING_CONTAINER using ports. Shutting it down..."; \
		docker stop $$CONFLICTING_CONTAINER; \
	else \
		echo "Ports $(HOST_RPC_PORT) and $(HOST_P2P_PORT) are clear."; \
	fi

# Query the containerized binary version output for rapid validation
.PHONY: test
test: verify-env
	@echo "Validating node binary functionality..."
	docker run --rm $(IMAGE_NAME):$(VERSION_TAG) --version
	@echo "Internal configuration tests passed."

# Help Menu Interface Documentation Engine
.PHONY: help
help:
	@echo "Bitcoin Core Custom Security Build System"
	@echo ""
	@echo "Usage:"
	@echo "  make build             Compile local architecture node image matching host context"
	@echo "  make build-multiarch   Compile and push multi-platform images simultaneously via Buildx"
	@echo "  make up                Stop existing nodes and launch the new version tag sequentially"
	@echo "  make stop              Find and tear down running node containers or port hijackers"
	@echo "  make test              Query the local container binary version for assurance"
	@echo "  make