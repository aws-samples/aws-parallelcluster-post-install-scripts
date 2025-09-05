#!/bin/bash

set -exo pipefail


NCCL_VERSION=${1:-v2.26.2-1} #compatible with OFI-NCCL v 1.14.2 preinstalled on pcluster AMI https://github.com/aws/aws-ofi-nccl/releases/tag/v1.14.2

# Install NCCL
if [ ! -d "/opt/nccl" ]; then
  git clone  --single-branch --branch ${NCCL_VERSION} https://github.com/NVIDIA/nccl.git /opt/nccl
  cd /opt/nccl
  # Explicitly specify platforms since building for all takes ~10 minutes
  # It takes 6 min 7 sec for 70,80,90
  make -j src.build NVCC_GENCODE="-gencode=arch=compute_70,code=sm_70 -gencode=arch=compute_80,code=sm_80 -gencode=arch=compute_90,code=sm_90"
fi

# Install nccl-tests
if [ ! -d "/opt/nccl-tests" ]; then
  git clone --depth=1 https://github.com/NVIDIA/nccl-tests.git /opt/nccl-tests
  cd /opt/nccl-tests
  export LD_LIBRARY_PATH=/opt/amazon/efa/lib:$LD_LIBRARY_PATH
  make -j $(nproc) MPI=1 MPI_HOME=/opt/amazon/openmpi NCCL_HOME=/opt/nccl/build CUDA_HOME=/usr/local/cuda
fi
