# Pyxis + Enroot

The script `postinstall.sh`  will install pyxis and enroot onto an instance. You'll need to set the shared directory you want to use as the `ENROOT_CACHE_PATH`:

```yaml
 CustomActions:
    OnNodeConfigured:
      Script: https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/multi-runner/postinstall.sh
      Args:
        - https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/pyxis/postinstall.sh
        - -/fsx
```