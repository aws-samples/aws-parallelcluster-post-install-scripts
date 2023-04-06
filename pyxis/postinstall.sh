#!/bin/bash
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

# Usage: ./postinstall.sh [shared_dir]
# default to /home/[default-user] which is available on all clusters
. /etc/parallelcluster/cfnconfig
SHARED_DIR=${1:-/home/$cfn_cluster_user}

set -o pipefail


########
#ENROOT
########
# enroot and pyxis versions should be hardcoded and will change with our release cycle
ENROOT_CONFIG_RELEASE=pyxis # TODO automate

sudo yum install -y jq squashfs-tools parallel fuse-overlayfs libnvidia-container-tools pigz squashfuse slurm-devel

export arch=$(uname -m)
sudo -E yum install -y https://github.com/NVIDIA/enroot/releases/download/v3.4.1/enroot-3.4.1-1.el8.${arch}.rpm
sudo -E yum install -y https://github.com/NVIDIA/enroot/releases/download/v3.4.1/enroot+caps-3.4.1-1.el8.${arch}.rpm

wget -O /tmp/enroot.template.conf https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/${ENROOT_CONFIG_RELEASE}/pyxis/enroot.template.conf
mkdir -p ${SHARED_DIR}/enroot
sudo chown ec2-user ${SHARED_DIR}/enroot
ENROOT_CACHE_PATH=${SHARED_DIR}/enroot envsubst < /tmp/enroot.template.conf > /tmp/enroot.conf
sudo mv /tmp/enroot.conf /etc/enroot/enroot.conf
sudo chmod 0644 /etc/enroot/enroot.conf


########
#PYXIS
########
git clone --depth 1 --branch v0.15.0 https://github.com/NVIDIA/pyxis.git /tmp/pyxis
cd /tmp/pyxis
sudo CPPFLAGS='-I /opt/slurm/include/' make
sudo CPPFLAGS='-I /opt/slurm/include/' make install
sudo mkdir -p /opt/slurm/etc/plugstack.conf.d
echo -e 'include /opt/slurm/etc/plugstack.conf.d/*' | sudo tee /opt/slurm/etc/plugstack.conf
sudo ln -fs /usr/local/share/pyxis/pyxis.conf /opt/slurm/etc/plugstack.conf.d/pyxis.conf

for f in /run/user /run/enroot; do sudo mkdir -p ${f} && sudo chown ec2-user ${f}; done # TODO: should we keep this?

sudo systemctl restart slurmd || sudo systemctl restart slurmctld || exit 0
