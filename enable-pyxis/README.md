
# Pyxis Configuration Scripts

This repository contains scripts to configure Pyxis and Enroot on AWS ParallelCluster nodes. These scripts enable containerized job execution using NVIDIA Pyxis (SLURM SPANK plugin) and NVIDIA Enroot.

## Prerequisites

- **AWS ParallelCluster version 3.11.1 or later**
- Official AWS ParallelCluster AMIs (which come with Pyxis and Enroot pre-installed)

## Scripts

The repository contains two main scripts:

### 1. Head Node Configuration (`./head-node/postscript.sh`)

This script configures Pyxis and Enroot on the head node. Include it as an OnNodeConfigured custom action in your ParallelCluster configuration.

### 2. Compute Node Configuration (`./compute-node/postscript.sh`)

This script configures Pyxis and Enroot on compute nodes. Include it as an OnNodeStart custom action in your ParallelCluster configuration.

## Usage

Include the following in your ParallelCluster config:

```yaml
HeadNode:
  CustomActions:
    OnNodeConfigured:
      Script: https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/enable-pyxis/head-node/postscript.sh
```
```yaml
Scheduling:
  CustomActions:
    OnNodeStart:
      Script: https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/enable-pyxis/compute-node/postscript.sh
```

For more details, please see here

https://docs.aws.amazon.com/parallelcluster/latest/ug/tutorials_11_running-containerized-jobs-with-pyxis.html