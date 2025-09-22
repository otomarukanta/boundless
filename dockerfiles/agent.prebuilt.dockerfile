# Dockerfile for pre-built bento-agent binary
# Usage: docker build -f dockerfiles/agent.prebuilt.dockerfile --build-arg BINARY_URL=<url> -t bento-agent:prebuilt .

ARG CUDA_RUNTIME_IMG=nvidia/cuda:13.0.1-runtime-ubuntu24.04
FROM ${CUDA_RUNTIME_IMG}

ARG BINARY_URL

# Install runtime dependencies matching non-prebuilt version
RUN apt-get update && \
    apt-get install -y ca-certificates libssl3 curl tar && \
    rm -rf /var/lib/apt/lists/*

# Download and extract bento bundle tar.gz
RUN if [ -z "$BINARY_URL" ]; then echo "ERROR: BINARY_URL is required" && exit 1; fi && \
    mkdir -p /app && \
    curl -L -o /tmp/bento-bundle.tar.gz "$BINARY_URL" && \
    tar -xzf /tmp/bento-bundle.tar.gz -C /tmp && \
    mv /tmp/bento-bundle/bento-agent /app/agent && \
    rm -rf /tmp/*

# TODO following rzup commands should likely only be done in a builder image to minimize image size
# Install RISC0 and groth16 component early for better caching
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
ENV RISC0_HOME=/usr/local/risc0
ENV PATH="/root/.cargo/bin:${PATH}"

# Install rust and target version (should match rust-toolchain.toml for best speed)
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y \
    && chmod -R a+w $RUSTUP_HOME $CARGO_HOME \
    && rustup install 1.88

# Install RISC0 specifically for groth16 component - this layer will be cached unless RISC0_HOME changes
RUN curl -L https://risczero.com/install | bash && \
    /root/.risc0/bin/rzup install risc0-groth16 && \
    # Clean up any temporary files to reduce image size
    rm -rf /tmp/* /var/tmp/*    

WORKDIR /app
ENTRYPOINT ["/app/agent"]