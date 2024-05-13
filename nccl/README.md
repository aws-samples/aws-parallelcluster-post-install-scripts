# NCCL

The script `postinstall.sh`  will install [nccl]() and [aws ofi nccl]() onto an instance. This postinstall script supports Ubuntu operating systems.

Include the following in your [HeadNode](https://docs.aws.amazon.com/parallelcluster/latest/ug/HeadNode-v3.html) and [Scheduling](https://docs.aws.amazon.com/parallelcluster/latest/ug/Scheduling-v3.html) sections of the parallelcluster config:

```yaml
 CustomActions:
    OnNodeConfigured:
      Sequence:
        - Script: https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/nccl/postinstall.sh
            - v2.21.5-1 # optional NCCL version
            - v1.9.1-aws # optional AWS OFI NCCL version
```

Note the versions `v2.21.5-1` and `v1.9.1-aws` must match the tag on their respective Github repositories exactly. See:
* [NCCL Releases](https://github.com/NVIDIA/nccl)
* [AWS OFI NCCL Releases](https://github.com/aws/aws-ofi-nccl/releases)
