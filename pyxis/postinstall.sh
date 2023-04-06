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
OS=$(. /etc/os-release; echo $NAME)

if [ "${OS}" == "Amazon Linux" ]; then
	nvidia-smi && distribution=$(. /etc/os-release;echo $ID$VERSION_ID) && curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.repo | sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo && sudo yum install libnvidia-container-tools -y
	sudo yum install -y jq squashfs-tools parallel fuse-overlayfs pigz squashfuse slurm-devel
	export arch=$(uname -m)
	sudo -E yum install -y https://github.com/NVIDIA/enroot/releases/download/v3.4.1/enroot-3.4.1-1.el8.${arch}.rpm
	sudo -E yum install -y https://github.com/NVIDIA/enroot/releases/download/v3.4.1/enroot+caps-3.4.1-1.el8.${arch}.rpm
  	export NONROOT_USER=ec2-user
elif [ "${OS}" == "Ubuntu" ]; then
	sudo apt update
	nvidia-smi && distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
	    && curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
		&& curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
			sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
		    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list \
	    && sudo apt-get update \
	    && sudo apt-get install libnvidia-container-tools nvidia-container-toolkit -y
	sudo apt-get install -y jq squashfs-tools parallel fuse-overlayfs pigz squashfuse slurm-devel
	export arch=$(dpkg --print-architecture)
	curl -fSsL -O https://github.com/NVIDIA/enroot/releases/download/v3.4.1/enroot_3.4.1-1_${arch}.deb
	curl -fSsL -O https://github.com/NVIDIA/enroot/releases/download/v3.4.1/enroot+caps_3.4.1-1_${arch}.deb # optional
	sudo apt install -y ./*.deb
  	export NONROOT_USER=ubuntu
else
	echo "Unsupported OS: ${OS}" && exit 1;
fi

ENROOT_CONFIG_RELEASE=pyxis # TODO automate
wget -O /tmp/enroot.template.conf https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/${ENROOT_CONFIG_RELEASE}/pyxis/enroot.template.conf
mkdir -p ${SHARED_DIR}/enroot
sudo chown ${NONROOT_USER} ${SHARED_DIR}/enroot
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

sudo systemctl restart slurmd || sudo systemctl restart slurmctld || exit 0
