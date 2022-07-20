# vmware 虚拟机初始配置
## 虚拟机初始化
### 网络通信
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
### yum 源变更
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
### 主机名设置
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
### 时间同步
ntpdate和chrony是服务器时间同步的主要工具，两者的主要区别：
- 执行ntpdate 后，时间是立即修整，中间会出现时间断档；
- 而执行chrony后，时间也会修正，但是是缓慢将时间追回，并不会断档。

使用chronyd服务平滑同步时间的方式要优于crontab + ntpdate，因为ntpdate同步时间会造成时间的跳跃，对一些依赖时间的程序和服务会造成影响，例如：sleep、timer等，且chronyd服务可以在修正时间的过程中同时修正CPU tick。

#### chrony
可使用 chrony，CentOS7系统默认已经安装</br>

https://chegva.com/3265.html</br>

https://help.aliyun.com/document_detail/187016.html </br>

```
[root@vm-centos7-64-k8s-master-01 ~]# systemctl status chronyd.service
● chronyd.service - NTP client/server
   Loaded: loaded (/usr/lib/systemd/system/chronyd.service; enabled; vendor preset: enabled)
   Active: active (running) since Tue 2022-07-19 21:31:34 EDT; 46min ago
     Docs: man:chronyd(8)
           man:chrony.conf(5)
  Process: 7954 ExecStartPost=/usr/libexec/chrony-helper update-daemon (code=exited, status=0/SUCCESS)
  Process: 7940 ExecStart=/usr/sbin/chronyd $OPTIONS (code=exited, status=0/SUCCESS)
 Main PID: 7948 (chronyd)
   CGroup: /system.slice/chronyd.service
           └─7948 /usr/sbin/chronyd

Jul 19 21:31:34 vm-centos7-64-k8s-master-01 systemd[1]: Starting NTP client/server...
Jul 19 21:31:34 vm-centos7-64-k8s-master-01 chronyd[7948]: chronyd version 3.2 starting (+CMDMON +NTP +REFCLOCK +RTC +PRIVDROP +SCFILTER +SECHASH +SIGND +ASYNCDNS +IPV6 +DEBUG)
Jul 19 21:31:34 vm-centos7-64-k8s-master-01 chronyd[7948]: Frequency -4.728 +/- 0.638 ppm read from /var/lib/chrony/drift
Jul 19 21:31:34 vm-centos7-64-k8s-master-01 systemd[1]: Started NTP client/server.
Jul 19 21:31:43 vm-centos7-64-k8s-master-01 chronyd[7948]: Selected source 144.76.76.107
Jul 19 21:31:47 vm-centos7-64-k8s-master-01 chronyd[7948]: Selected source 139.199.214.202
Jul 19 21:34:01 vm-centos7-64-k8s-master-01 chronyd[7948]: Source 193.182.111.142 replaced with 162.159.200.123


# 时区不对
[root@vm-centos7-64-k8s-master-01 ~]# date
Tue Jul 19 22:19:25 EDT 2022

```
使用 chrony 作为时间同步 client，时间同步源设置为阿里源，设置时区为上海</br>
https://developer.aliyun.com/article/831625
https://help.aliyun.com/document_detail/92704.html
```
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
```
查询结果
```
[root@vm-centos7-64-k8s-master-01 ~]# chronyc -n sources -v
210 Number of sources = 5

  .-- Source mode  '^' = server, '=' = peer, '#' = local clock.
 / .- Source state '*' = current synced, '+' = combined , '-' = not combined,
| /   '?' = unreachable, 'x' = time may be in error, '~' = time too variable.
||                                                 .- xxxx [ yyyy ] +/- zzzz
||      Reachability register (octal) -.           |  xxxx = adjusted offset,
||      Log2(Polling interval) --.      |          |  yyyy = measured offset,
||                                \     |          |  zzzz = estimated error.
||                                 |    |           \
MS Name/IP address         Stratum Poll Reach LastRx Last sample               
===============================================================================
^? 94.237.64.20                  2   6     1     1    +93ms[  +93ms] +/-  118ms
^? 94.130.49.186                 3   6     1     0  -1826us[-1826us] +/-  112ms
^? 119.28.183.184                2   6     1     0   -478us[ -478us] +/-   13ms
^? 162.159.200.123               3   6     1     0  +2856us[+2856us] +/-  111ms
^? 203.107.6.88                  2   4     1     1  +1316us[+1316us] +/-   27ms

[root@vm-centos7-64-k8s-master-01 ~]# cat cat /etc/chrony.conf
cat: cat: No such file or directory
# Use public servers from the pool.ntp.org project.
# Please consider joining the pool (http://www.pool.ntp.org/join.html).
server 0.centos.pool.ntp.org iburst
server 1.centos.pool.ntp.org iburst
server 2.centos.pool.ntp.org iburst
server 3.centos.pool.ntp.org iburst
server ntp.aliyun.com minpoll 4 maxpoll 10 iburst

# Record the rate at which the system clock gains/losses time.
driftfile /var/lib/chrony/drift

# Allow the system clock to be stepped in the first three updates
# if its offset is larger than 1 second.
makestep 1.0 3

# Enable kernel synchronization of the real-time clock (RTC).
rtcsync

# Enable hardware timestamping on all interfaces that support it.
#hwtimestamp *

# Increase the minimum number of selectable sources required to adjust
# the system clock.
#minsources 2

# Allow NTP client access from local network.
#allow 192.168.0.0/16

# Serve time even if not synchronized to a time source.
#local stratum 10

# Specify file containing keys for NTP authentication.
#keyfile /etc/chrony.keys

# Specify directory for log files.
logdir /var/log/chrony

# Select which information is logged.
#log measurements statistics tracking

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

