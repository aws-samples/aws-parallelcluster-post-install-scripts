# AWS ParallelCluster Post-Install Scripts 🚀

This repo contains a set of scripts that can be used to customize AWS ParallelCluster. To use multiple, take advantage of the `multi-runner` script like so:

```yaml
 CustomActions:
    OnNodeConfigured:
      Script: https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/multi-runner/postinstall.sh
      Args:
        - https://script1.com
        - -arg1
        - -arg2
        - https://script2.com
        - -arg1
```

| **Script**     | **URL**                                                                                         | **Description**                                       |
|----------------|-------------------------------------------------------------------------------------------------|-------------------------------------------------------|
| Spack Setup 👾    | `https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/spack/postinstall.sh` | Setup Spack Package Manager                           |
| Multi-Runner 🪄   | `https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/multi-runner/postinstall.sh`   | Run Multiple Post-install scripts including arguments |
| SLURM Rest API 🛰️ | `https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/rest-api/postinstall.sh`   | Setup the Slurm REST API                              |
| Pyxis + Enroot 📦 | `https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/pyxis/postinstall.sh`                                                                                              | Run containers with Slurm using Pyxis and Enroot. Tested on `alinux2` and `ubuntu2004`.     |
