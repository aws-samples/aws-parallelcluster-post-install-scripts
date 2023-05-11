# !/bin/bash
set -e


OS=$(. /etc/os-release; echo $NAME)

if [ "${OS}" = "Amazon Linux" ]; then
    yum update
    yum search docker
    yum info docker
    yum install docker
    usermod -a -G ec2-user
    id ec2-user
    newgrp docker
    systemctl enable docker.service
    systemctl start docker.service
elif [ "${OS}" = "Ubuntu" ]; then
    apt-get -y update
    apt-get -y install \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    mkdir -m 0755 -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get -y update
    apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    #groupadd docker
    chgrp docker $(which docker)
    chmod g+s $(which docker)
    #usermod -aG docker ubuntu
    #newgrp docker
    systemctl enable docker.service
    systemctl start docker.service

else
        echo "Unsupported OS: ${OS}" && exit 1;
fi

