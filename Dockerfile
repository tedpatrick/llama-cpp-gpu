FROM nvidia/cuda:12.3.1-devel-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_DOCKER_ARCH=all

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    cmake \
    libcurl4-openssl-dev \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Clone and build llama.cpp with CUDA support
WORKDIR /opt
RUN git clone https://github.com/ggml-org/llama.cpp

WORKDIR /opt/llama.cpp
RUN cmake -B build -DGGML_CUDA=ON && \
    cmake --build build --config Release -j$(nproc)

# Add llama.cpp binaries to PATH
ENV PATH="/opt/llama.cpp/build/bin:${PATH}"

# Set working directory
WORKDIR /workspace

# Copy and set up the startup script
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Default command
CMD ["/usr/local/bin/start.sh"]