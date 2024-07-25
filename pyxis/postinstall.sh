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

STABLE=1
ENROOT_RELEASE=3.4.1	# For STABLE=1
PYXIS_RELEASE=v0.19.0

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
	FUSE_OVERLAYFS_URL=http://mirror.centos.org/centos/7/extras/x86_64/Packages/fuse-overlayfs-0.7.2-6.el7_8.x86_64.rpm
	FUSE_OVERLAYFS_RPM=${FUSE_OVERLAYFS_URL##*/}   # fuse-overlayfs-xxx.rpm

	if [ $GPU_PRESENT -eq 0 ] && [ $GPU_CONTAINER_PRESENT -gt 0 ]; then
		distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
		&& curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.repo | tee /etc/yum.repos.d/nvidia-container-toolkit.repo \
		&& sudo yum clean expire-cache -y \
		&& yum update -y \
		&& yum install libnvidia-container-tools -y
	fi

	# alinux2 doesn't have fuse-overlayfs in its repos. So, the question is: which "alinux" this
	# script was originall written for, to assume that it provides fuse-overlayfs?
	yum install -y jq squashfs-tools parallel fuse-overlayfs pigz squashfuse zstd
	if [[ ! -e /usr/bin/fuse-overlays ]]; then
		wget $FUSE_OVERLAYFS_URL
		yum localinstall -y $FUSE_OVERLAYFS_RPM
		rm $FUSE_OVERLAYFS_RPM
	fi

	if [[ $STABLE == 1 ]]; then
		export arch=$(uname -m)
		# QUESTION: alinux2 is el7?
		yum install -y https://github.com/NVIDIA/enroot/releases/download/v${ENROOT_RELEASE}/enroot-${ENROOT_RELEASE}-1.el8.${arch}.rpm
		yum install -y https://github.com/NVIDIA/enroot/releases/download/v${ENROOT_RELEASE}/enroot+caps-${ENROOT_RELEASE}-1.el8.${arch}.rpm
	else
		yum install -y git gcc make libcap libtool automake libmd-devel
		pushd /opt
		git clone https://github.com/NVIDIA/enroot.git && cd enroot
		prefix=/usr sysconfdir=/etc make install	# NOTE: produce lots of log lines (gcc) to CW
		prefix=/usr sysconfdir=/etc make setcap
		popd
	fi
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
	apt-get install -y jq squashfs-tools parallel fuse-overlayfs pigz squashfuse zstd
	if [[ $STABLE == 1 ]]; then
		export arch=$(dpkg --print-architecture)
		curl -fSsL -O https://github.com/NVIDIA/enroot/releases/download/v${ENROOT_RELEASE}/enroot_${ENROOT_RELEASE}-1_${arch}.deb
		curl -fSsL -O https://github.com/NVIDIA/enroot/releases/download/v${ENROOT_RELEASE}/enroot+caps_${ENROOT_RELEASE}-1_${arch}.deb # optional
		apt install -y ./*.deb
	else
		apt install -y git gcc make libcap2-bin libtool automake libmd-dev
		pushd /opt
		git clone https://github.com/NVIDIA/enroot.git && cd enroot
		prefix=/usr sysconfdir=/etc make install	# NOTE: produce lots of log lines (gcc) to CW
		prefix=/usr sysconfdir=/etc make setcap
		popd
	fi
	ln -s /usr/share/enroot/hooks.d/50-slurm-pmi.sh /etc/enroot/hooks.d/
	ln -s /usr/share/enroot/hooks.d/50-slurm-pytorch.sh /etc/enroot/hooks.d/

	# https://github.com/NVIDIA/enroot/issues/136#issuecomment-1241257854
	mkdir -p /etc/sysconfig
	echo "PATH=/opt/slurm/sbin:/opt/slurm/bin:$(bash -c 'source /etc/environment ; echo $PATH')" >> /etc/sysconfig/slurmd
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

# Permissions
mkdir -p /tmp/enroot
chmod 1777 /tmp/enroot
mkdir -p /tmp/enroot/data
chmod 1777 /tmp/enroot/data

chmod 1777 ${SHARED_DIR}/enroot

########
#PYXIS
########
git clone --depth 1 --branch ${PYXIS_RELEASE} https://github.com/NVIDIA/pyxis.git /tmp/pyxis
cd /tmp/pyxis
CPPFLAGS='-I /opt/slurm/include/' make
CPPFLAGS='-I /opt/slurm/include/' make install
mkdir -p /opt/slurm/etc/plugstack.conf.d
echo -e 'include /opt/slurm/etc/plugstack.conf.d/*' | tee /opt/slurm/etc/plugstack.conf
ln -fs /usr/local/share/pyxis/pyxis.conf /opt/slurm/etc/plugstack.conf.d/pyxis.conf

mkdir -p ${SHARED_DIR}/pyxis/
chown ${NONROOT_USER} ${SHARED_DIR}/pyxis/
sed -i '${s/$/ runtime_path=${SHARED_DIR}\/pyxis/}' /opt/slurm/etc/plugstack.conf.d/pyxis.conf
SHARED_DIR=${SHARED_DIR} envsubst < /opt/slurm/etc/plugstack.conf.d/pyxis.conf > /opt/slurm/etc/plugstack.conf.d/pyxis.tmp.conf
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
