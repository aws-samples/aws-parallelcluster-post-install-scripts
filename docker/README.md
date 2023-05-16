# Docker

The script `postinstall.sh`  will install docker onto an instance. This postinstall script supports ubunutu and alinux2 operating systems.

```yaml
 CustomActions:
    OnNodeConfigured:
      Script: https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/multi-runner/postinstall.sh
      Args:
        - https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/docker/postinstall.sh
```

