#! /bin/bash

yum -y install chrony

systemctl enable chronyd
systemctl start chronyd

mv /etc/localtime /tmp/localtime.bak
ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

hwclock -w
timedatectl status

chronyc tracking
chronyc -n sources -v


# add aliyun ntp server
cp -a /etc/chrony.conf /tmp/chrony.conf.bak

sed -i '/server\ 3\.centos\.pool\.ntp\.org\ iburst/aserver ntp.aliyun.com minpoll 4 maxpoll 10 iburst'  /etc/chrony.conf
cat /etc/chrony.conf


systemctl restart chronyd.service
chronyc -n sources -v
