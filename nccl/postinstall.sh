#!/bin/bash

set -exo pipefail

NCCL_VERSION=${1:-v2.21.5-1}
AWS_OFI_NCCL_VERSION=${2:-v1.9.1-aws}

# Install NCCL
if [ ! -d "/opt/nccl" ]; then
  git clone  --single-branch --branch ${NCCL_VERSION} https://github.com/NVIDIA/nccl.git /opt/nccl
  cd /opt/nccl
  # Explicitly specify platforms since building for all takes ~10 minutes.
  # Pick GENCODE based on the available CUDA toolkit:
  #   - CUDA >= 13 dropped sm_70 (V100); cover Ampere/Hopper/Blackwell.
  #   - CUDA <  13 still supports sm_70; keep V100 in the matrix.
  # In both cases, sm_100 (B200/Blackwell) is required to avoid
  # 'Cuda failure: named symbol not found' on p6-b200 instances.
  CUDA_MAJOR=$(/usr/local/cuda/bin/nvcc --version | grep -oP 'release \K[0-9]+' | head -1)
  if [ "${CUDA_MAJOR:-0}" -ge 13 ]; then
    NCCL_GENCODE="-gencode=arch=compute_80,code=sm_80 \
                  -gencode=arch=compute_90,code=sm_90 \
                  -gencode=arch=compute_100,code=sm_100 \
                  -gencode=arch=compute_120,code=compute_120"
  else
    NCCL_GENCODE="-gencode=arch=compute_70,code=sm_70 \
                  -gencode=arch=compute_80,code=sm_80 \
                  -gencode=arch=compute_90,code=sm_90 \
                  -gencode=arch=compute_100,code=sm_100 \
                  -gencode=arch=compute_100,code=compute_100"
  fi
  make -j src.build NVCC_GENCODE="${NCCL_GENCODE}"
fi

# Install nccl-tests
if [ ! -d "/opt/nccl-tests" ]; then
  git clone --depth=1 --branch v2.16.9 https://github.com/NVIDIA/nccl-tests.git /opt/nccl-tests
  cd /opt/nccl-tests
  export LD_LIBRARY_PATH=/opt/amazon/efa/lib:$LD_LIBRARY_PATH
  make -j $(nproc) MPI=1 MPI_HOME=/opt/amazon/openmpi NCCL_HOME=/opt/nccl/build CUDA_HOME=/usr/local/cuda
fi

# Install AWS OFI NCCL
if [ ! -d "/opt/aws-ofi-nccl" ]; then
  git clone -b ${AWS_OFI_NCCL_VERSION} --depth=1 https://github.com/aws/aws-ofi-nccl.git /opt/aws-ofi-nccl
  cd /opt/aws-ofi-nccl
  ./autogen.sh
  ./configure --enable-platform-aws \
            --with-libfabric=/opt/amazon/efa \
            --with-mpi=/opt/amazon/openmpi \
            --with-cuda=/usr/local/cuda \
            --prefix=/opt/aws-ofi-nccl
  make -j $(nproc)
  make install
fi
