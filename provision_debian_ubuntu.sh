#!/bin/bash

apt-get update
apt-get install \
     apt-transport-https \
     ca-certificates \
     curl \
     gnupg2 \
     software-properties-common \
     vim  tree  telnet git jq
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
groupadd docker
usermod -aG docker $USER

mkdir -p /etc/systemd/system/docker.service.d
touch /etc/systemd/system/docker.service.d/docker.conf
cat <<EOF > /etc/systemd/system/docker.service.d/docker.conf
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H tcp://0.0.0.0:4243 -H unix:///var/run/docker.sock
EOF

systemctl enable docker
systemctl daemon-reload
systemctl restart docker

curl --silent "https://api.github.com/repos/docker/compose/releases/latest" | jq --arg PLATFORM_ARCH "$(echo `uname -s`-`uname -m`)" -r '.assets[] | select(.name | endswith($PLATFORM_ARCH)).browser_download_url' | xargs sudo curl -L -o /usr/local/bin/docker-compose --url
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

echo GRUB_CMDLINE_LINUX="cgroup_enable=memory swapaccount=1" >> /etc/default/grub
update-grub
