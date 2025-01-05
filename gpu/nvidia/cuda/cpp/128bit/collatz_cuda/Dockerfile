FROM nvidia/cuda:12.6.1-devel-ubuntu22.04

# Install essentials
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the source code into the container
COPY kernel_collatz.cu /app/

# Compile with nvcc
RUN nvcc -o kernel_collatz kernel_collatz.cu

# Default command
CMD ["./kernel_collatz"]
#CMD ["nvidia-smi"]
#CMD ["ls -la"]
