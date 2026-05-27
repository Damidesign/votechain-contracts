# Multi-stage Dockerfile for VoteChain Contracts
# Stage 1: Builder
FROM rust:1.84-slim as builder

# Set working directory
WORKDIR /build

# Install dependencies required for Rust and WASM compilation
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy project files
COPY . .

# Add WASM target
RUN rustup target add wasm32-unknown-unknown

# Install Stellar CLI with optimizations enabled
RUN cargo install --locked stellar-cli --features opt

# Build the WASM contracts
RUN cargo build --target wasm32-unknown-unknown --release

# Run tests
RUN cargo test

# Stage 2: Development Environment
FROM rust:1.84-slim as development

WORKDIR /work

# Install minimal runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    pkg-config \
    libssl-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Add WASM target
RUN rustup target add wasm32-unknown-unknown

# Copy compiled artifacts and dependencies from builder
COPY --from=builder /usr/local/cargo/bin/stellar /usr/local/cargo/bin/stellar
COPY --from=builder /build/target /work/target
COPY . .

# Create a script for convenient contract building
RUN echo '#!/bin/bash\nset -euo pipefail\nstellar contract build\n' > /usr/local/bin/build-contracts && \
    chmod +x /usr/local/bin/build-contracts

# Default to building contracts
ENTRYPOINT ["bash"]
CMD ["-c", "echo 'VoteChain Development Environment' && bash"]

# Stage 3: Minimal Runtime (for CI/artifact storage)
FROM debian:12-slim as runtime

WORKDIR /contracts

# Install minimal runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy only the built WASM artifacts
COPY --from=builder /build/target/wasm32-unknown-unknown/release/*.wasm /contracts/

# Copy deployment scripts
COPY scripts/ /contracts/scripts/
COPY config/ /contracts/config/

# Make scripts executable
RUN chmod +x /contracts/scripts/*.sh

# Document what's in this image
RUN echo "VoteChain Contract Artifacts" > /contracts/README.txt && \
    echo "Built WASM binaries:" >> /contracts/README.txt && \
    ls -lh /contracts/*.wasm >> /contracts/README.txt 2>/dev/null || echo "  (built during container creation)" >> /contracts/README.txt

# Set default command to list artifacts
CMD ["ls", "-lah", "/contracts"]
