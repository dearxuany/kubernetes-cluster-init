# kubernetes-cluster-init
## kubernetes 简述
### 常见部署方式
- 调试
  - minikube
  - kind
- 集群
  - kubeadmin
  - rancher rke
  - 云平台 ACK 托管集群

### 组件
https://kubernetes.io/zh-cn/docs/concepts/overview/components/#container-runtime
#### 集群必要组件
- 客户端
  - kubectl
- master
  - kube-apiserver
    - CRD
    - Operator  
      https://www.redhat.com/zh/topics/containers/what-is-a-kubernetes-operator
  - kube-controller-manager
  - kube-scheduler
  - etcd
- node
  - kubelet
  - kube-proxy
     - iptables
     - ipvs
  - container runtime
     - docker

#### 常用组件
- cloud-controller-manager
  - Node Controller
  - Route Controller
  - Service Controller
- dns
  - CoreDNS
- nginx-ingress-controller
- log-controller


### 接口
- CRI
  - docker (k8s 1.24 后不支持)
- CNI
  - flannel
  - calico
  - canal
  - terway
- CSI
  - ceph
  - glusterfs
  - nas


## kubeadmin 部署 k8s 集群
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

虚拟机配置

| host                      | ip              | cpu | ram | dish |   system   |   |   |
|---------------------------|-----------------|-----|-----|------|------------|---|---|
|vm-centos7-64-k8s-master-01| 192.168.126.137 | 4   | 4GB | 20GB | centos7 64 |   |   |
|vm-centos7-64-k8s-master-02| 192.168.126.138 |     |     |      | centos7 64 |   |   |
|vm-centos7-64-k8s-master-03| 192.168.126.139 |     |     |      | centos7 64 |   |   |
|vm-centos7-64-k8s-node-01  | 192.168.126.140 |     |     |      |            |   |   |
|vm-centos7-64-k8s-node-02  | 192.168.126.141 |     |     |      |            |   |   |

组件版本

| 组件            | 版本                     | 部署位置 | 部署方式     |   |
|----------------|-------------------------|---------|------------|---|
| kubernetes     |                         |         |            |   |
| docker         | docker-ce-19.03.5-3.el7 | 全量     | systemd    |   |
| kubeadm        |                         |         |            |   |
| kubelet        |                         |         |            |   |
| kube-proxy     |                         |         |            |   |
| kubectl        |                         | client  | yum        |   |
|                |                         |         |            |   |
|                |                         |         |            |   |




### VM 虚拟机初始配置(所有节点)
#### 初始化详细配置
见 [vmware 虚拟机初始配置及 k8s 适配调优](docs/vmware-host-init.md)

#### kube-proxy 默认 iptable 桥接流量启用及 ipvs 启用
##### iptable
激活 br_netfilter 模块，确保 br_netfilter 模块被加载。
这一操作可以通过运行 lsmod | grep br_netfilter 来完成。若要显式加载该模块，可执行 sudo modprobe br_netfilter。
为了让你的 Linux 节点上的 iptables 能够正确地查看桥接流量，你需要确保在你的 sysctl 配置中将 net.bridge.bridge-nf-call-iptables 设置为 1。
```
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
```
使以上参数立即生效
```
[root@vm-centos7-64-k8s-master-01 ~]# sudo sysctl --system
* Applying /usr/lib/sysctl.d/00-system.conf ...
net.bridge.bridge-nf-call-ip6tables = 0
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-arptables = 0
* Applying /usr/lib/sysctl.d/10-default-yama-scope.conf ...
kernel.yama.ptrace_scope = 0
* Applying /usr/lib/sysctl.d/50-default.conf ...
kernel.sysrq = 16
kernel.core_uses_pid = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.promote_secondaries = 1
net.ipv4.conf.all.promote_secondaries = 1
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
* Applying /etc/sysctl.d/99-sysctl.conf ...
* Applying /etc/sysctl.d/k8s.conf ...
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
* Applying /etc/sysctl.conf ...
```
查看当前系统已加载的内核模块
```
[root@vm-centos7-64-k8s-master-01 ~]# lsmod|grep ip_vs
[root@vm-centos7-64-k8s-master-01 ~]# lsmod
Module                  Size  Used by
br_netfilter           22256  0 
ip_set                 45644  0 
nfnetlink              14490  1 ip_set
bridge                151336  1 br_netfilter
stp                    12976  1 bridge

```

##### ipvs
开启 ipvs,不开启 ipvs 将会使用 iptables，但是效率低，所以官网推荐需要开通 ipvs 内核，参考 https://blog.csdn.net/weixin_42808782/article/details/116716809
```
# ipvs 依赖
yum install -y ipset ipvsadm
```
启用 ipvs 内核模块
```
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
```
ipvs 启用确认
```
[root@vm-centos7-64-k8s-master-01 ~]# lsmod | grep -e ip_vs -e nf_conntrack_ipv4
nf_conntrack_ipv4      15053  0 
nf_defrag_ipv4         12729  1 nf_conntrack_ipv4
ip_vs_sh               12688  0 
ip_vs_wrr              12697  0 
ip_vs_rr               12600  0 
ip_vs                 145497  6 ip_vs_rr,ip_vs_sh,ip_vs_wrr
nf_conntrack          133095  2 ip_vs,nf_conntrack_ipv4
libcrc32c              12644  3 xfs,ip_vs,nf_conntrack
```

#### 容器运行时组件 docker
Docker Engine 没有实现 CRI，而这是容器运行时在 Kubernetes 中工作所需要的。 为此，必须安装一个额外的服务 cri-dockerd。 cri-dockerd 是一个基于传统的内置Docker引擎支持的项目，它在 1.24 版本从 kubelet 中移除。

https://kubernetes.io/zh-cn/docs/setup/production-environment/container-runtimes/

此处使用 k8s 版本为 kubernetes 1.23 故可以继续使用 Docker Engine 来作为容器运行时组件。

```
[root@vm-centos7-64-k8s-master-01 ~]# cat docker-install.sh 
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

```
docker daemon.json 文件
```
[root@vm-centos7-64-k8s-master-01 tmp]# cat  /etc/docker/daemon.json
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "10"
    },
    "bip": "169.254.123.1/24",     # docker 容器使用网段，不能和内网网段冲突
    "oom-score-adjust": -1000,
    "registry-mirrors": ["https://pqbap4ya.mirror.aliyuncs.com"],
    "storage-driver": "overlay2",
    "storage-opts":["overlay2.override_kernel_check=true"],
    "live-restore": true
}
```
以上 docker daemon.json 文件 使用默认 /var/lib/docker 目录作为容器的存储与运行目录，修改需变更 Docker Root Dir
参数
```
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "10"
    },
    "bip": "169.254.123.1/24",
    "oom-score-adjust": -1000,
    "registry-mirrors": ["https://pqbap4ya.mirror.aliyuncs.com"],
    "storage-driver": "overlay2",
    "storage-opts":["overlay2.override_kernel_check=true"],
    "data-root":"/sdata/docker",
    "live-restore": true
}
```
docker info
```
[root@vm-centos7-64-k8s-master-01 ~]# docker info
Client:
 Context:    default
 Debug Mode: false
 Plugins:
  app: Docker App (Docker Inc., v0.9.1-beta3)
  buildx: Docker Buildx (Docker Inc., v0.8.2-docker)
  scan: Docker Scan (Docker Inc., v0.17.0)

Server:
 Containers: 0
  Running: 0
  Paused: 0
  Stopped: 0
 Images: 0
 Server Version: 19.03.5
 Storage Driver: overlay2
  Backing Filesystem: xfs
  Supports d_type: true
  Native Overlay Diff: true
 Logging Driver: json-file
 Cgroup Driver: systemd
 Plugins:
  Volume: local
  Network: bridge host ipvlan macvlan null overlay
  Log: awslogs fluentd gcplogs gelf journald json-file local logentries splunk syslog
 Swarm: inactive
 Runtimes: runc
 Default Runtime: runc
 Init Binary: docker-init
 containerd version: 10c12954828e7c7c9b6e0ea9b0c02b01407d3ae1
 runc version: v1.1.2-0-ga916309
 init version: fec3683
 Security Options:
  seccomp
   Profile: default
 Kernel Version: 3.10.0-957.el7.x86_64
 Operating System: CentOS Linux 7 (Core)
 OSType: linux
 Architecture: x86_64
 CPUs: 2
 Total Memory: 3.692GiB
 Name: vm-centos7-64-k8s-master-01
 ID: FWZS:TTKC:OQNX:IDSC:2RIJ:TQHA:UEYL:TYPV:M5TE:JHWA:6B4F:XOSP
 Docker Root Dir: /var/lib/docker
 Debug Mode: false
 Registry: https://index.docker.io/v1/
 Labels:
 Experimental: false
 Insecure Registries:
  127.0.0.0/8
 Registry Mirrors:
  https://pqbap4ya.mirror.aliyuncs.com/
 Live Restore Enabled: true

```

#### 安装 kubeadm、kubelet 和 kubectl
- kubeadm：用来初始化集群的指令
- kubelet：在集群中的每个节点上用来启动 Pod 和容器等
- kubectl：用来与集群通信的命令行工具


kubeadm、kubelet 和 kubectl 版本需要和 kubernetes 版本兼容，此处组件均选择 1.23 对应版本

https://kubernetes.io/zh-cn/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#version-skew-policy

https://kubernetes.io/zh-cn/releases/version-skew-policy/

设置 kubernetes yum 源为阿里云
```
#! /bin/bash
#由于官方源位于国外，这里配置centos7 kubernetes国内阿里源
cat << EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
```
查看 yum 源版本，安装版本为 1.23.9 的 kubeadm、kubelet、kubectl
```
[root@vm-centos7-64-k8s-master-01 ~]# cat kubeadm-kubelet-kubectl-install.sh 
#! /bin/bash

# check versions
yum list kubelet kubeadm kubectl  --showduplicates|sort -r|grep 1.23


yum install -y kubelet-1.23.9 kubeadm-1.23.9 kubectl-1.23.9 --disableexcludes=kubernetes

sleep 10

sudo systemctl enable --now kubelet && systemctl start kubelet

kubeadm version
kubectl version --client
kubelet --version

```
返回
```
Created symlink from /etc/systemd/system/multi-user.target.wants/kubelet.service to /usr/lib/systemd/system/kubelet.service.```
```
查看版本
```
# kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"23", GitVersion:"v1.23.9", GitCommit:"c1de2d70269039fe55efb98e737d9a29f9155246", GitTreeState:"clean", BuildDate:"2022-07-13T14:25:37Z", GoVersion:"go1.17.11", Compiler:"gc", Platform:"linux/amd64"}

# kubectl version --client
Client Version: version.Info{Major:"1", Minor:"23", GitVersion:"v1.23.9", GitCommit:"c1de2d70269039fe55efb98e737d9a29f9155246", GitTreeState:"clean", BuildDate:"2022-07-13T14:26:51Z", GoVersion:"go1.17.11", Compiler:"gc", Platform:"linux/amd64"}

# kubelet --version
Kubernetes v1.23.9
```
其中 kubelet 没有启动成功
```
[root@vm-centos7-64-k8s-master-01 ~]# systemctl status kubelet
● kubelet.service - kubelet: The Kubernetes Node Agent
   Loaded: loaded (/usr/lib/systemd/system/kubelet.service; enabled; vendor preset: disabled)
  Drop-In: /usr/lib/systemd/system/kubelet.service.d
           └─10-kubeadm.conf
   Active: activating (auto-restart) (Result: exit-code) since Wed 2022-07-20 15:51:09 CST; 7s ago
     Docs: https://kubernetes.io/docs/
  Process: 20042 ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS (code=exited, status=1/FAILURE)
 Main PID: 20042 (code=exited, status=1/FAILURE)

Jul 20 15:51:09 vm-centos7-64-k8s-master-01 systemd[1]: kubelet.service: main process exited, code=exited, status=1/FAILURE
Jul 20 15:51:09 vm-centos7-64-k8s-master-01 systemd[1]: Unit kubelet.service entered failed state.
Jul 20 15:51:09 vm-centos7-64-k8s-master-01 systemd[1]: kubelet.service failed.

```
需要确保容器运行时和 kubelet 所使用的是相同的 cgroup 驱动，否则 kubelet 进程会失败
```
[root@vm-centos7-64-k8s-master-01 ~]# cat /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
# Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
# This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
EnvironmentFile=-/etc/sysconfig/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS

```
kubelet 启动文件添加 KUBELET_CGROUP_ARGS 配置

https://kubernetes.io/zh-cn/docs/tasks/administer-cluster/kubeadm/configure-cgroup-driver/#%E8%BF%81%E7%A7%BB%E5%88%B0-systemd-%E9%A9%B1%E5%8A%A8

```
[root@vm-centos7-64-k8s-master-01 ~]# vim /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
Environment="KUBELET_CGROUP_ARGS=--system-reserved=memory=300Mi --kube-reserved=memory=400Mi --eviction-hard=imagefs.available<15%,memory.available<300Mi,nodefs.available<10%,nodefs.inodesFree<5% --cgroup-driver=systemd"
# This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
EnvironmentFile=-/etc/sysconfig/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS

```
加载配置后重启 kubelet
```
[root@vm-centos7-64-k8s-master-01 ~]# systemctl daemon-reload
[root@vm-centos7-64-k8s-master-01 ~]# systemctl stop kubelet
[root@vm-centos7-64-k8s-master-01 ~]# systemctl start kubelet
[root@vm-centos7-64-k8s-master-01 ~]# systemctl status kubelet
● kubelet.service - kubelet: The Kubernetes Node Agent
   Loaded: loaded (/usr/lib/systemd/system/kubelet.service; enabled; vendor preset: disabled)
  Drop-In: /usr/lib/systemd/system/kubelet.service.d
           └─10-kubeadm.conf
   Active: active (running) since Wed 2022-07-20 16:11:49 CST; 2ms ago
     Docs: https://kubernetes.io/docs/
 Main PID: 20858 (kubelet)
    Tasks: 1
   Memory: 120.0K
   CGroup: /system.slice/kubelet.service
           └─20858 /usr/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml

Jul 20 16:11:49 vm-centos7-64-k8s-master-01 systemd[1]: kubelet.service holdoff time over, scheduling restart.
Jul 20 16:11:49 vm-centos7-64-k8s-master-01 systemd[1]: Stopped kubelet: The Kubernetes Node Agent.
Jul 20 16:11:49 vm-centos7-64-k8s-master-01 systemd[1]: Started kubelet: The Kubernetes Node Agent.

```
