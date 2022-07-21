#!/usr/bin/env bash
# https://docs.docker.com/engine/install/centos/
# https://help.aliyun.com/document_detail/51853.html

docker_daemon_json_enable="True"
docker_daemon_json_tpl="./docker-daemon.json"

sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine

sudo yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2

sudo wget -O /etc/yum.repos.d/docker-ce.repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
sudo yum list docker-ce --showduplicates|grep 19.03.5

sudo yum install -y docker-ce-19.03.5-3.el7 docker-ce-cli containerd.io

if [ $docker_daemon_json_enable = "True" ];then
  if [ ! -d /etc/docker ]; then
    sudo mkdir -p /etc/docker
  fi
  if [ -f "/etc/docker/daemon.json" ]; then
    mv /etc/docker/daemon.json /tmp/docker-daemon.json.bak.$(date "+%Y%m%d%H%M%S")
  fi
  sudo mv $docker_daemon_json_tpl /etc/docker/daemon.json
fi

sudo systemctl start docker
sudo systemctl enable docker
sudo systemctl status docker

sudo docker info
