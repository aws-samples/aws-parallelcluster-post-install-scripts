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
###########################################
# BEGIN: post-install enroot & pyxis config
###########################################
"

## Get AWS ParallelCluster Version
### Probably there is a better way.
INSTANCE_ID=$(cat /sys/devices/virtual/dmi/id/board_asset_tag | tr -d " ")

PC_VERSION=$(cat /opt/parallelcluster/.bootstrapped | awk -F'-' '{print $4}' | awk -F. '{print $1"."$2}')

if (( $(echo "$PC_VERSION > 3.11" | bc -l ) ));
then

	if [ "$cfn_node_type" == "HeadNode" ];
	then

		echo "Executing $0"

		# Configure Enroot
		ENROOT_DIR=${1:-/tmp/enroot}

		sudo mkdir -p $ENROOT_DIR
		sudo mkdir -p $ENROOT_DIR/data
		sudo mkdir -p $ENROOT_DIR/cache
		sudo chmod -R 1777 $ENROOT_DIR
		sudo cp /opt/parallelcluster/examples/enroot/enroot.conf /etc/enroot/enroot.conf
		sudo chmod 0644 /etc/enroot/enroot.conf

		sudo sed -i "s%^ENROOT_CONFIG_PATH.*%ENROOT_CONFIG_PATH          /home/\$(id -u -n)/.config/enroot%g" /etc/enroot/enroot.conf
		sudo sed -i "s%^ENROOT_RUNTIME_PATH.*%ENROOT_RUNTIME_PATH         $ENROOT_DIR/user-\$(id -u)%g" /etc/enroot/enroot.conf
		sudo sed -i "s%^ENROOT_DATA_PATH.*%ENROOT_DATA_PATH            $ENROOT_DIR/data/user-\$(id -u)%g" /etc/enroot/enroot.conf
		sudo sed -i "s%^ENROOT_CACHE_PATH.*%ENROOT_CACHE_PATH           $ENROOT_DIR/cache/user-\$(id -u)%g" /etc/enroot/enroot.conf

		# Configure Pyxis
		PYXIS_RUNTIME_DIR="/run/pyxis"

		sudo mkdir -p $PYXIS_RUNTIME_DIR
		sudo chmod 1777 $PYXIS_RUNTIME_DIR

		sudo mkdir -p /opt/slurm/etc/plugstack.conf.d/
		sudo cp /opt/parallelcluster/examples/spank/plugstack.conf /opt/slurm/etc/
		sudo cp /opt/parallelcluster/examples/pyxis/pyxis.conf /opt/slurm/etc/plugstack.conf.d/
		sudo -i scontrol reconfigure  

	fi


	if [ "$cfn_node_type" == "ComputeFleet" ];
	then
		echo "Executing $0"

		# Configure Enroot
		ENROOT_DIR=${1:-/local_scratch/enroot}

		sudo mkdir -p $ENROOT_DIR
		sudo mkdir -p $ENROOT_DIR/data
		sudo mkdir -p $ENROOT_DIR/cache
		sudo chmod -R 1777 $ENROOT_DIR
		sudo cp /opt/parallelcluster/examples/enroot/enroot.conf /etc/enroot/enroot.conf
		sudo chmod 0644 /etc/enroot/enroot.conf

		sudo sed -i "s%^ENROOT_CONFIG_PATH.*%ENROOT_CONFIG_PATH          /home/\$(id -u -n)/.config/enroot%g" /etc/enroot/enroot.conf
		sudo sed -i "s%^ENROOT_RUNTIME_PATH.*%ENROOT_RUNTIME_PATH         $ENROOT_DIR/user-\$(id -u)%g" /etc/enroot/enroot.conf
		sudo sed -i "s%^ENROOT_DATA_PATH.*%ENROOT_DATA_PATH            $ENROOT_DIR/data/user-\$(id -u)%g" /etc/enroot/enroot.conf
		sudo sed -i "s%^ENROOT_CACHE_PATH.*%ENROOT_CACHE_PATH           $ENROOT_DIR/cache/user-\$(id -u)%g" /etc/enroot/enroot.conf

		# Configure Pyxis
		PYXIS_RUNTIME_DIR="/run/pyxis"

		sudo mkdir -p $PYXIS_RUNTIME_DIR
		sudo chmod 1777 $PYXIS_RUNTIME_DIR

		wget -O /etc/chef/cookbooks/aws-parallelcluster-slurm/templates/default/compute_node_finalize/slurm/slurm.sysconfig.erb https://raw.githubusercontent.com/aws/aws-parallelcluster-cookbook/refs/heads/develop/cookbooks/aws-parallelcluster-slurm/templates/default/compute_node_finalize/slurm/slurm.sysconfig.erb
		echo "PATH=/opt/slurm/sbin:/opt/slurm/bin:$(bash -c 'source /etc/environment ; echo $PATH')" >> /etc/chef/cookbooks/aws-parallelcluster-slurm/templates/default/compute_node_finalize/slurm/slurm.sysconfig.erb

		systemctl is-active --quiet slurmd    && systemctl restart slurmd    || echo "This instance does not run slurmd"

	fi
else

	STABLE=1
	ENROOT_RELEASE=3.5.0	# For STABLE=1
	PYXIS_RELEASE=v0.20.0

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

		# fuse-overlayfs is now available from the Extra Packages for Enterprise Linux repo via yum
	 	amazon-linux-extras install epel
		yum install -y epel-release	
		yum install -y jq squashfs-tools parallel fuse-overlayfs pigz squashfuse zstd

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
	  	export NONROOT_USER=ubuntu
	else
		echo "Unsupported OS: ${OS}" && exit 1;
	fi

	ln -s /usr/share/enroot/hooks.d/50-slurm-pmi.sh /etc/enroot/hooks.d/
	ln -s /usr/share/enroot/hooks.d/50-slurm-pytorch.sh /etc/enroot/hooks.d/

	# https://github.com/NVIDIA/enroot/issues/136#issuecomment-1241257854
	mkdir -p /etc/sysconfig
	wget -O /etc/chef/cookbooks/aws-parallelcluster-slurm/templates/default/compute_node_finalize/slurm/slurm.sysconfig.erb https://raw.githubusercontent.com/aws/aws-parallelcluster-cookbook/refs/heads/develop/cookbooks/aws-parallelcluster-slurm/templates/default/compute_node_finalize/slurm/slurm.sysconfig.erb
	echo "PATH=/opt/slurm/sbin:/opt/slurm/bin:$(bash -c 'source /etc/environment ; echo $PATH')" >> /etc/chef/cookbooks/aws-parallelcluster-slurm/templates/default/compute_node_finalize/slurm/slurm.sysconfig.erb


	ENROOT_CONFIG_RELEASE=main # TODO automate
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


	########
	#GPU
	########
	if [ $GPU_PRESENT -gt 0 ] && [ $GPU_CONTAINER_PRESENT -gt 0 ]; then
		echo "GPUs not present, stopping early!"
		exit 0
	fi

	nvidia-container-cli --load-kmods info || true

	systemctl is-active --quiet slurmctld && systemctl restart slurmctld || echo "This instance does not run slurmctld"
	systemctl is-active --quiet slurmd    && systemctl restart slurmd    || echo "This instance does not run slurmd"


fi

echo "
#########################################
# END: post-install enroot & pyxis config
#########################################
"
