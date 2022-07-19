# vmware 虚拟机初始配置
## 虚拟机初始化
设置 VM 虚拟机的 host IP 及外网访问，VMWare 为 NAT 模式
https://www.cnblogs.com/bkyyay/p/12507184.html
https://blog.csdn.net/eeeemon/article/details/109661426

```
# 宿主机 windows 
C:\Users\IT>ipconfig

Windows IP 配置


以太网适配器 VMware Network Adapter VMnet1:

   连接特定的 DNS 后缀 . . . . . . . :
   本地链接 IPv6 地址. . . . . . . . : fe80::11d7:2bef:8e62:5be8%18
   IPv4 地址 . . . . . . . . . . . . : 192.168.134.1
   子网掩码  . . . . . . . . . . . . : 255.255.255.0
   默认网关. . . . . . . . . . . . . :

以太网适配器 VMware Network Adapter VMnet8:

   连接特定的 DNS 后缀 . . . . . . . :
   本地链接 IPv6 地址. . . . . . . . : fe80::e83e:259:2ad7:f52d%10
   IPv4 地址 . . . . . . . . . . . . : 192.168.126.1
   子网掩码  . . . . . . . . . . . . : 255.255.255.0
   默认网关. . . . . . . . . . . . . :



# VM linux
[root@localhost ~]# cd /etc/sysconfig/network-scripts/

[root@localhost network-scripts]# ls
ifcfg-ens33  ifdown-bnep  ifdown-ipv6  ifdown-ppp     ifdown-Team      ifup          ifup-eth   ifup-isdn   ifup-post    ifup-sit       ifup-tunnel       network-functions
ifcfg-lo     ifdown-eth   ifdown-isdn  ifdown-routes  ifdown-TeamPort  ifup-aliases  ifup-ippp  ifup-plip   ifup-ppp     ifup-Team      ifup-wireless     network-functions-ipv6
ifdown       ifdown-ippp  ifdown-post  ifdown-sit     ifdown-tunnel    ifup-bnep     ifup-ipv6  ifup-plusb  ifup-routes  ifup-TeamPort  init.ipv6-global


[root@localhost network-scripts]# cat /etc/sysconfig/network-scripts/ifcfg-ens33 
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static   # 固定IP，禁用 DHCP
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=ens33
UUID=3a8680f5-911c-4f52-80f2-9870ad1c7d4f
DEVICE=ens33
ONBOOT=yes
IPADDR=192.168.126.137   # 设置一个和虚拟网卡在同一子网的IP
NETMASK=255.255.255.0
GATEWAY=192.168.126.2    # VMware Network Adapter VMnet8 网关，VMware 的 NAT 模式网关为x.x.x.2
DNS1=8.8.8.8             # 外部 DNS 服务器

[root@localhost network-scripts]# ip add
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:0c:29:3c:27:9c brd ff:ff:ff:ff:ff:ff
    inet 192.168.126.137/24 brd 192.168.126.255 scope global noprefixroute ens33
       valid_lft forever preferred_lft forever
    inet6 fe80::ec2d:6078:8dab:dbb0/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever



[root@localhost network-scripts]# ping www.baidu.com
PING www.a.shifen.com (14.215.177.38) 56(84) bytes of data.
64 bytes from 14.215.177.38 (14.215.177.38): icmp_seq=1 ttl=128 time=4.31 ms
64 bytes from 14.215.177.38 (14.215.177.38): icmp_seq=2 ttl=128 time=3.16 ms
64 bytes from 14.215.177.38 (14.215.177.38): icmp_seq=3 ttl=128 time=2.78 ms
^C
--- www.a.shifen.com ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2003ms
rtt min/avg/max/mdev = 2.784/3.421/4.315/0.650 ms

```
设置 yum 源为阿里云
https://developer.aliyun.com/mirror/centos?spm=a2c6h.13651102.0.0.3e221b11iHFqLD
```
[root@localhost ~]# cat yum-init.sh 
#! /bin/bash
mv /etc/yum.repos.d/CentOS-Base.repo /tmp/
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
sleep 30
yum makecache
```
常用工具 yum 安装
```
[root@localhost ~]# cat tools-init.sh 
#! /bin/bash
yum install -y wget telnet net-tools glances bind-utils lrzsz lsof ipset ipvsadm vim
```
设置主机名，SSH 重新登录生效
```
# 方法1
[root@localhost ~]# hostnamectl set-hostname vm-centos7-64-k8s-master-01
[root@localhost ~]# hostname
vm-centos7-64-k8s-master-01

# 方法2
[root@localhost ~]# cat /etc/hostname 
vm-centos7-64-k8s-master-01
[root@localhost ~]# cat /etc/hostname > /proc/sys/kernel/hostname
[root@localhost ~]# hostname
vm-centos7-64-k8s-master-01

[root@vm-centos7-64-k8s-master-01 ~]# ifconfig
ens33: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.126.137  netmask 255.255.255.0  broadcast 192.168.126.255
        inet6 fe80::ec2d:6078:8dab:dbb0  prefixlen 64  scopeid 0x20<link>
        ether 00:0c:29:3c:27:9c  txqueuelen 1000  (Ethernet)
        RX packets 297  bytes 28139 (27.4 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 241  bytes 37267 (36.3 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 68  bytes 5920 (5.7 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 68  bytes 5920 (5.7 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

```

## 虚拟机 k8s 适配调优
### 关闭防火墙和 selinux
centos7 防火墙默认开启需关闭
```
[root@vm-centos7-64-k8s-master-01 ~]# systemctl status firewalld
● firewalld.service - firewalld - dynamic firewall daemon
   Loaded: loaded (/usr/lib/systemd/system/firewalld.service; enabled; vendor preset: enabled)
   Active: active (running) since Tue 2022-07-19 01:40:04 EDT; 27min ago
     Docs: man:firewalld(1)
 Main PID: 7934 (firewalld)
   CGroup: /system.slice/firewalld.service
           └─7934 /usr/bin/python -Es /usr/sbin/firewalld --nofork --nopid

Jul 19 01:40:02 vm-centos7-64-k8s-master-01 systemd[1]: Starting firewalld - dynamic firewall daemon...
Jul 19 01:40:04 vm-centos7-64-k8s-master-01 systemd[1]: Started firewalld - dynamic firewall daemon.
```
永久关闭防火墙
```
#! /bin/bash

# 关闭防火墙
systemctl stop firewalld && systemctl disable firewalld
sed -i '/^SELINUX=/c SELINUX=disabled' /etc/selinux/config
setenforce 0

systemctl status firewalld
```

### 关闭 SWAP 分区
```
#关闭swap
swapoff -a
sed -i 's/^.*centos-swap/#&/g' /etc/fstab
```

### 本地主机名解析
虚拟机 /etc/hosts 设置主机解析 （有私网 dns 的话就不需要）
```
[root@vm-centos7-64-k8s-master-01 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

[root@vm-centos7-64-k8s-master-01 ~]# ip route ls
default via 192.168.126.2 dev ens33 proto static metric 100 
192.168.126.0/24 dev ens33 proto kernel scope link src 192.168.126.137 metric 100 
```
修改 hosts
```
# 本地 hosts 解析非必要
cat << EOF >> /etc/hosts
192.168.126.137 vm-centos7-64-k8s-master-01
192.168.126.138 vm-centos7-64-k8s-master-02
192.168.126.139 vm-centos7-64-k8s-master-03
192.168.126.140 vm-centos7-64-k8s-node-01
192.168.126.141 vm-centos7-64-k8s-node-02
EOF


[root@vm-centos7-64-k8s-master-01 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.126.137 vm-centos7-64-k8s-master-01
192.168.126.138 vm-centos7-64-k8s-master-02 
192.168.126.139 vm-centos7-64-k8s-master-03
192.168.126.140 vm-centos7-64-k8s-node-01  
192.168.126.141 vm-centos7-64-k8s-node-02

[root@vm-centos7-64-k8s-master-01 ~]# ping vm-centos7-64-k8s-master-02
PING vm-centos7-64-k8s-master-02 (192.168.126.138) 56(84) bytes of data.
```

