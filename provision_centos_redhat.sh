#!/bin/bash

rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum update
yum install -y python36.x86_64
rm -rf /usr/bin/python
ln -s /usr/bin/python3.6 /usr/bin/python3
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python get-pip.py

yum remove docker docker-common docker-selinux docker-engine
yum install -y yum-utils device-mapper-persistent-data lvm2 vim tree telnet git jq
 
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y http://mirror.centos.org/centos/7/extras/x86_64/Packages/container-selinux-2.21-1.el7.noarch.rpm
yum install -y docker-ce
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
sysctl net.bridge.bridge-nf-call-iptables=1
sysctl net.bridge.bridge-nf-call-ip6tables=1

curl --silent "https://api.github.com/repos/docker/compose/releases/latest" | jq --arg PLATFORM_ARCH "$(echo `uname -s`-`uname -m`)" -r '.assets[] | select(.name | endswith($PLATFORM_ARCH)).browser_download_url' | xargs sudo curl -L -o /usr/local/bin/docker-compose --url
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose