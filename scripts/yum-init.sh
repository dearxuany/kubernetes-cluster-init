#! /bin/bash
mv /etc/yum.repos.d/CentOS-Base.repo /tmp/
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
sleep 30
yum makecache
