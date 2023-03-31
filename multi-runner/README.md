# AWS ParallelCluster Multi-Post-Install script

The following script runs other post-install scripts provided as arguments to [OnNodeConfigured](https://docs.aws.amazon.com/parallelcluster/latest/ug/HeadNode-v3.html#yaml-HeadNode-CustomActions-OnNodeConfigured).

```bash
#!/usr/bin/env python3
# Copyright 2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance
# with the License. A copy of the License is located at
#
# http://aws.amazon.com/apache2.0/
#
# or in the "LICENSE.txt" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, express or implied. See the License for the specific language governing permissions and
# limitations under the License.
import sys
import tempfile
import os
import subprocess


def main():
    args = sys.argv[1:][::-1]
    scripts = []
    while len(args) > 0:
        if args[-1] == "":
            continue
        if args[-1][0] == "-":
            scripts[-1].append(args[-1][1:])
        else:
            scripts.append([args[-1]])
        args.pop()

    sub_env = os.environ.copy()

    with open("/opt/parallelcluster/cfnconfig", "r") as file:
        for line in file.read().splitlines():
            env_key, env_val = line.split("=")
            sub_env[env_key] = env_val

    print(sub_env)

    for script in scripts:
        path = script[0]
        args = script[1:]

        script_data = subprocess.run(["wget", "-O-", path], capture_output=True, check=True)
        tmp = tempfile.NamedTemporaryFile(delete=True)
        with open(tmp.name, "wb") as file:
            file.write(script_data.stdout)

        os.chmod(tmp.name, 0o777)
        tmp.file.close()
        subprocess.run([tmp.name, *args], check=True, env=sub_env)


if __name__ == "__main__":
    main()
```

## Setup

1. Create a script called `postinstall.sh` with the above contents.
2. Upload your script to an S3 Bucket
3. Update your cluster config as shown below. Args are specified by adding an additional `-` proceeding the arg. Scripts are only fetched via `wget` for now but this would be easy to update to S3.

```yaml
 CustomActions:
    OnNodeConfigured:
      Script: s3://bucket/postinstall.sh
      Args:
        - https://script1.com
        - -arg1
        - https://script2.com
        - -arg1
```