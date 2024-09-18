# Pyxis + Enroot

The script `postinstall.sh`  will install pyxis and enroot onto an instance. Shared container cache path is set to `ENROOT_CACHE_PATH` which should be ideally located on shared filesystem. It will be set to home directory by default, you can override it by setting first positinal argument to your shared FS path:

Include the following in your [HeadNode](https://docs.aws.amazon.com/parallelcluster/latest/ug/HeadNode-v3.html) and [Scheduling](https://docs.aws.amazon.com/parallelcluster/latest/ug/Scheduling-v3.html) sections of the parallelcluster config.


```yaml
  CustomActions:
    OnNodeConfigured:
      Sequence:
        - Script: https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/pyxis/postinstall.sh
          Args:
            - /fsx
```

# Private docker registry
Enroot supports [private docker registry](https://github.com/NVIDIA/enroot/blob/9c6e979059699e93cfc1cce0967b78e54ad0e263/doc/cmd/import.md#description), [AWS ECR](https://aws.amazon.com/ecr/) among others. You can define your own config file that has to be placed on `ENROOT_CONFIG_PATH` from `enroot.template.conf`.

For example, Amazon ECR requires authentication to pull containers.
You will need to define credentials in `$HOME/.config/enroot/.crendentials`.

```txt
machine 159553542841.dkr.ecr.us-west-2.amazonaws.com login AWS password $(aws ecr get-login-password --region us-west-2)
```

You will then be able to import container images from Amazon ECR with enroot:

```bash
enroot import docker://159553542841.dkr.ecr.us-west-2.amazonaws.com/nccl-tests:efa1.34.0-ofiv1.11.0-aws-ncclv2.23.4-1-testsv2.13.10
```

Expected output
```txt
[INFO] Querying registry for permission grant
[INFO] Authenticating with user: AWS
[INFO] Using credentials from file: /home/maxhaws/.config/enroot/.credentials
[INFO] Authentication succeeded
[INFO] Fetching image manifest list
[INFO] Fetching image manifest
[INFO] Downloading 1 missing layers...
```
