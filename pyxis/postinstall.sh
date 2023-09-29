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
set -exo pipefail

. /etc/parallelcluster/cfnconfig
SHARED_DIR=${1:-/home/$cfn_cluster_user}

echo "
###################################
# BEGIN: post-install pyxis
###################################
"

########
#ENROOT
########
# enroot and pyxis versions should be hardcoded and will change with our release cycle
OS=$(. /etc/os-release; echo $NAME)

# We do not suport adding driver yet and rely on parallelcluster AMI and DLAMI for nvidia drivers.
# We would like to investigate using CPU parallelcluster AMI and using Nvidia driver through container, the open question is how to make healthchecks use it.
nvidia-smi && export GPU_PRESENT=0 || GPU_PRESENT=-1;
if [ $GPU_PRESENT -eq 0 ]; then
	nvidia-container-cli info && export GPU_CONTAINER_PRESENT=0 || export GPU_CONTAINER_PRESENT=-1
else
	export GPU_CONTAINER_PRESENT=1
fi

if [ "${OS}" == "Amazon Linux" ]; then
	if [ $GPU_PRESENT -eq 0 ] && [ $GPU_CONTAINER_PRESENT -gt 0 ]; then
		distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
		&& curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.repo | tee /etc/yum.repos.d/nvidia-container-toolkit.repo \
		&& sudo yum clean expire-cache -y \
		&& yum update -y \
		&& yum install libnvidia-container-tools -y
	fi
	yum install -y jq squashfs-tools parallel fuse-overlayfs pigz squashfuse
	export arch=$(uname -m)
	yum install -y https://github.com/NVIDIA/enroot/releases/download/v3.4.1/enroot-3.4.1-1.el8.${arch}.rpm
	yum install -y https://github.com/NVIDIA/enroot/releases/download/v3.4.1/enroot+caps-3.4.1-1.el8.${arch}.rpm
  	export NONROOT_USER=ec2-user
elif [ "${OS}" == "Ubuntu" ]; then
	apt update
	if [ $GPU_PRESENT -eq 0 ] && [ $GPU_CONTAINER_PRESENT -gt 0 ]; then
		distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
	    	&& curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
		&& curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
		    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
		    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list \
	    	&& apt-get update -y \
	    	&& apt-get install libnvidia-container-tools -y
	fi
	apt-get install -y jq squashfs-tools parallel fuse-overlayfs pigz squashfuse
	export arch=$(dpkg --print-architecture)
	curl -fSsL -O https://github.com/NVIDIA/enroot/releases/download/v3.4.1/enroot_3.4.1-1_${arch}.deb
	curl -fSsL -O https://github.com/NVIDIA/enroot/releases/download/v3.4.1/enroot+caps_3.4.1-1_${arch}.deb # optional
	apt install -y ./*.deb
  	export NONROOT_USER=ubuntu
else
	echo "Unsupported OS: ${OS}" && exit 1;
fi

ENROOT_CONFIG_RELEASE=pyxis # TODO automate
wget -O /tmp/enroot.template.conf https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/${ENROOT_CONFIG_RELEASE}/pyxis/enroot.template.conf
mkdir -p ${SHARED_DIR}/enroot
chown ${NONROOT_USER} ${SHARED_DIR}/enroot
ENROOT_CACHE_PATH=${SHARED_DIR}/enroot envsubst < /tmp/enroot.template.conf > /tmp/enroot.conf
mv /tmp/enroot.conf /etc/enroot/enroot.conf
chmod 0644 /etc/enroot/enroot.conf


########
#PYXIS
########
git clone --depth 1 --branch v0.15.0 https://github.com/NVIDIA/pyxis.git /tmp/pyxis
cd /tmp/pyxis
CPPFLAGS='-I /opt/slurm/include/' make
CPPFLAGS='-I /opt/slurm/include/' make install
mkdir -p /opt/slurm/etc/plugstack.conf.d
echo -e 'include /opt/slurm/etc/plugstack.conf.d/*' | tee /opt/slurm/etc/plugstack.conf
ln -fs /usr/local/share/pyxis/pyxis.conf /opt/slurm/etc/plugstack.conf.d/pyxis.conf

mkdir -p ${SHARED_DIR}/pyxis/
chown ${NONROOT_USER} ${SHARED_DIR}/pyxis/
sed -i '${s/$/ runtime_path=${SHARED_DIR}\/pyxis/}' /opt/slurm/etc/plugstack.conf.d/pyxis.conf
envsubst < /opt/slurm/etc/plugstack.conf.d/pyxis.conf > /opt/slurm/etc/plugstack.conf.d/pyxis.tmp.conf
mv /opt/slurm/etc/plugstack.conf.d/pyxis.tmp.conf /opt/slurm/etc/plugstack.conf.d/pyxis.conf

systemctl restart slurmd || systemctl restart slurmctld



########
#GPU
########
if [ $GPU_PRESENT -gt 0 ] && [ $GPU_CONTAINER_PRESENT -gt 0 ]; then
	echo "GPUs not present, stopping early!"
	exit 0
fi

nvidia-container-cli --load-kmods info || true

systemctl restart slurmd || systemctl restart slurmctld

echo "
###################################
# END: post-install pyxis
###################################
"
