#! /bin/bash

# 关闭防火墙
systemctl stop firewalld && systemctl disable firewalld
sed -i '/^SELINUX=/c SELINUX=disabled' /etc/selinux/config
setenforce 0

systemctl status firewalld


# 关闭swap
swapoff -a
sed -i 's/^.*centos-swap/#&/g' /etc/fstab


# 本地 hosts 解析主机名，有私有 dns 非必要
cat << EOF >> /etc/hosts
192.168.126.137 vm-centos7-64-k8s-master-01
192.168.126.138 vm-centos7-64-k8s-master-02 
192.168.126.139 vm-centos7-64-k8s-master-03
192.168.126.140 vm-centos7-64-k8s-node-01  
192.168.126.141 vm-centos7-64-k8s-node-02
EOF

cat /etc/hosts


# iptable 配置
# 激活 br_netfilter 模块
modprobe br_netfilter
cat << EOF > /etc/modules-load.d/k8s.conf
br_netfilter
EOF
# 内核参数设置：开启IP转发，允许iptables对bridge的数据进行处理
cat << EOF > /etc/sysctl.d/k8s.conf 
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
# 启用 iptable 配置参数
sudo sysctl --system


# ipvs 启用
cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF
chmod 755 /etc/sysconfig/modules/ipvs.modules
bash /etc/sysconfig/modules/ipvs.modules
lsmod | grep -e ip_vs -e nf_conntrack_ipv4





