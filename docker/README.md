# Docker

The script `postinstall.sh`  will install docker onto an instance. This postinstall script supports ubunutu and alinux2 operating systems.

Include the following in your [HeadNode](https://docs.aws.amazon.com/parallelcluster/latest/ug/HeadNode-v3.html) and [Scheduling](https://docs.aws.amazon.com/parallelcluster/latest/ug/Scheduling-v3.html) sections of the parallelcluster config:

```yaml
 CustomActions:
    OnNodeConfigured:
      Sequence:
        - Script: https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/docker/postinstall.sh
```

