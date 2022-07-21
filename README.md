# kubernetes-cluster-init
## kubernetes 简述
### 常见部署方式
- 调试
  - minikube
  - kind
- 集群
  - kubeadm
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


## kubeadm 部署 k8s 集群
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

虚拟机配置

| host                      | ip              | cpu | ram | dish |   system   |   |   |
|---------------------------|-----------------|-----|-----|------|------------|---|---|
|vm-centos7-64-k8s-master-01| 192.168.126.137 | 2   | 4GB | 20GB | centos7 64 |   |   |
|vm-centos7-64-k8s-master-02| 192.168.126.138 |     |     |      | centos7 64 |   |   |
|vm-centos7-64-k8s-master-03| 192.168.126.139 |     |     |      | centos7 64 |   |   |
|vm-centos7-64-k8s-worker-01| 192.168.126.140 |     |     |      |            |   |   |
|vm-centos7-64-k8s-worker-02| 192.168.126.141 |     |     |      |            |   |   |

组件版本

| 组件            | 版本                     | 部署位置 | 部署/管理方式  |   |
|----------------|-------------------------|---------|--------------|---|
| kubernetes     | 1.23.9                  |         |              |   |
| docker         | docker-ce-19.03.5-3.el7 | 全量VM   | systemd      |   |
| kubeadm        | 1.23.9                  | 全量VM   | yum          |   |
| kubelet        | 1.23.9                  | 全量VM   | systemd      |   |
| kubectl        | 1.23.9                  | client  | yum          |   |
| kube-proxy     |                         |         |              |   |
|                |                         |         |              |   |
|                |                         |         |              |   |




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
docker CRI 的  "cgroup driver" 属性，需要和 kubelet 相同
```
[root@vm-centos7-64-k8s-master-01 ~]# docker info |grep Cgroup
 Cgroup Driver: systemd

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
kubelet 可启动，但会频繁自动重启，原因在于 kubelet 在等待 kubeadm 指令。升级时，kubelet 每隔几秒钟重新启动一次， 在 crashloop 状态中等待 kubeadm 发布指令。crashloop 状态是正常现象。 初始化控制平面后，kubelet 将正常运行。
```
[root@vm-centos7-64-k8s-master-01 ~]# journalctl -xe -u kubelet

err="failed to load Kubelet config file /var/lib/kubelet/config.yaml, error failed to read kubelet config file \"/var/lib/kubelet/config.yaml\", error: open /var/lib/kubelet/config.yaml: no such file or directory" path="/var/lib/kubelet/config.yaml"
```


### kubeadm 初始化 k8s cluster
https://kubernetes.io/zh-cn/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/

#### 单个 control-plane node 集群
kubeadm 初始化集群
https://kubernetes.io/zh-cn/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network

kubeadm 使用及参数解析
https://kubernetes.io/zh-cn/docs/reference/setup-tools/kubeadm/kubeadm-init/

##### master 节点初始化
kubeadm 可使用命令或者配置文件形式注入参数初始化启动 k8s 节点，此处先使用命令
````
kubeadm init \
--apiserver-advertise-address=192.168.126.137 \
--apiserver-bind-port 6443 \
--image-repository registry.aliyuncs.com/google_containers \
--kubernetes-version=v1.23.9 \
--service-cidr=10.96.0.0/12 \
--pod-network-cidr=10.244.0.0/16 \
--token-ttl=0
````
参数解析
```
--apiserver-advertise-address
  apiserver 通告给其他组件的IP地址，一般应该为Master节点的用于集群内部通信的IP地址
--apiserver-bind-port 
  API 服务器绑定的端口，默认 6443，master 间需保证该端口能相互访问
--image-repository 
  拉取镜像的镜像仓库，默认是k8s.gcr.io
--kubernetes-version
  指定kubernetes版本，默认是 stable-1
--service-cidr
  k8s service ClusterIP 分配的 VIP 网段，需和 CNI 插件配置一致，默认为 10.96.0.0/12
--pod-network-cidr
  k8s pod 分配的独立 IP 使用网段，需和 CNI 插件配置一致
  通常，Flannel网络插件的默认为10.244.0.0/16，Calico插件的默认值为192.168.0.0/16
--token-ttl
  默认token的有效期为24小时，如果不想过期，可以加上--token-ttl=0
```

其中，k8s 节点初始化的网络规划需要提前预估容量，多个因素会相互影响限制集群可支持的节点数与 pod 容量：

- 节点网卡支持 IP 数量，对于阿里云来说，每个 ECS 对应网卡支持的 IP 数量是有限制的，故限制了每个节点可支持的 pod 数量
- 节点磁盘容量和介质，主要是镜像存储大小和位置，涉及 docker 的 /var/lib/docker，如果分配太少的话会成为瓶颈
- k8s 集群网段规划必须在集群建立时就做好，集群建立后若网段 IP 不足则无法扩容，必须重新新建集群
- 


kubeadm 执行结果
```
[root@vm-centos7-64-k8s-master-01 docker]# kubeadm init \
> --apiserver-advertise-address=192.168.126.137 \
> --apiserver-bind-port 6443 \
> --image-repository registry.aliyuncs.com/google_containers \
> --kubernetes-version=v1.23.9 \
> --service-cidr=10.96.0.0/12 \
> --pod-network-cidr=10.244.0.0/16 \
> --token-ttl=0
[init] Using Kubernetes version: v1.23.9
[preflight] Running pre-flight checks
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "ca" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local vm-centos7-64-k8s-master-01] and IPs [10.96.0.1 192.168.126.137]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/ca" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [localhost vm-centos7-64-k8s-master-01] and IPs [192.168.126.137 127.0.0.1 ::1]
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [localhost vm-centos7-64-k8s-master-01] and IPs [192.168.126.137 127.0.0.1 ::1]
[certs] Generating "etcd/healthcheck-client" certificate and key
[certs] Generating "apiserver-etcd-client" certificate and key
[certs] Generating "sa" key and public key
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "kubelet.conf" kubeconfig file
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Starting the kubelet
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
[apiclient] All control plane components are healthy after 13.003710 seconds
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config-1.23" in namespace kube-system with the configuration for the kubelets in the cluster
NOTE: The "kubelet-config-1.23" naming of the kubelet ConfigMap is deprecated. Once the UnversionedKubeletConfigMap feature gate graduates to Beta the default name will become just "kubelet-config". Kubeadm upgrade will handle this transition transparently.
[upload-certs] Skipping phase. Please see --upload-certs
[mark-control-plane] Marking the node vm-centos7-64-k8s-master-01 as control-plane by adding the labels: [node-role.kubernetes.io/master(deprecated) node-role.kubernetes.io/control-plane node.kubernetes.io/exclude-from-external-load-balancers]
[mark-control-plane] Marking the node vm-centos7-64-k8s-master-01 as control-plane by adding the taints [node-role.kubernetes.io/master:NoSchedule]
[bootstrap-token] Using token: mm82pb.stvxhld7s8o49nuu
[bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstrap-token] Creating the "cluster-info" ConfigMap in the "kube-public" namespace
[kubelet-finalize] Updating "/etc/kubernetes/kubelet.conf" to point to a rotatable kubelet client certificate and key
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.126.137:6443 --token mm82pb.stvxhld7s8o49nuu \
	--discovery-token-ca-cert-hash sha256:8075d0258bbd9eb3f19fa04fdaafe29f9ee0970464b6220bd3afbcb48b222735 

```
kubectl 的 kubeconfig 默认生成在 /etc/kubernetes/admin.conf 中，可以搬到其他位置
```
[root@vm-centos7-64-k8s-master-01 docker]# kubectl get namespaces --kubeconfig /etc/kubernetes/admin.conf
NAME              STATUS   AGE
default           Active   6m16s
kube-node-lease   Active   6m18s
kube-public       Active   6m18s
kube-system       Active   6m18s


[root@vm-centos7-64-k8s-master-01 docker]# kubectl get all -A --kubeconfig /etc/kubernetes/admin.conf
NAMESPACE     NAME                                                      READY   STATUS    RESTARTS   AGE
kube-system   pod/coredns-6d8c4cb4d-mmlqb                               0/1     Pending   0          8m40s
kube-system   pod/coredns-6d8c4cb4d-r6g6z                               0/1     Pending   0          8m41s
kube-system   pod/etcd-vm-centos7-64-k8s-master-01                      1/1     Running   0          8m55s
kube-system   pod/kube-apiserver-vm-centos7-64-k8s-master-01            1/1     Running   0          8m55s
kube-system   pod/kube-controller-manager-vm-centos7-64-k8s-master-01   1/1     Running   0          8m55s
kube-system   pod/kube-proxy-fnv9z                                      1/1     Running   0          8m41s
kube-system   pod/kube-scheduler-vm-centos7-64-k8s-master-01            1/1     Running   0          8m55s

NAMESPACE     NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
default       service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP                  8m57s
kube-system   service/kube-dns     ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   8m56s

NAMESPACE     NAME                        DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
kube-system   daemonset.apps/kube-proxy   1         1         1       1            1           kubernetes.io/os=linux   8m56s

NAMESPACE     NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
kube-system   deployment.apps/coredns   0/2     2            0           8m56s

NAMESPACE     NAME                                DESIRED   CURRENT   READY   AGE
kube-system   replicaset.apps/coredns-6d8c4cb4d   2         2         0       8m41s

```
master 节点的 kubelet 状态，kubeadm init 后可正常 running
```
[root@vm-centos7-64-k8s-master-01 docker]# systemctl status kubelet
● kubelet.service - kubelet: The Kubernetes Node Agent
   Loaded: loaded (/usr/lib/systemd/system/kubelet.service; enabled; vendor preset: disabled)
  Drop-In: /usr/lib/systemd/system/kubelet.service.d
           └─10-kubeadm.conf
   Active: active (running) since Thu 2022-07-21 15:50:40 CST; 9min ago
     Docs: https://kubernetes.io/docs/
 Main PID: 24571 (kubelet)
    Tasks: 14
   Memory: 44.3M
   CGroup: /system.slice/kubelet.service
           └─24571 /usr/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.y...

Jul 21 16:00:05 vm-centos7-64-k8s-master-01 kubelet[24571]: E0721 16:00:05.995812   24571 kubelet.go:2391] "Container runtime network not ready" networkReady="Networ...tialized"
Jul 21 16:00:06 vm-centos7-64-k8s-master-01 kubelet[24571]: I0721 16:00:06.404720   24571 cni.go:240] "Unable to update cni config" err="no networks found in /etc/cni/net.d"
Jul 21 16:00:11 vm-centos7-64-k8s-master-01 kubelet[24571]: E0721 16:00:11.005869   24571 kubelet.go:2391] "Container runtime network not ready" networkReady="Networ...tialized"
Jul 21 16:00:11 vm-centos7-64-k8s-master-01 kubelet[24571]: I0721 16:00:11.405634   24571 cni.go:240] "Unable to update cni config" err="no networks found in /etc/cni/net.d"
Jul 21 16:00:16 vm-centos7-64-k8s-master-01 kubelet[24571]: E0721 16:00:16.072336   24571 kubelet.go:2391] "Container runtime network not ready" networkReady="Networ...tialized"
Jul 21 16:00:16 vm-centos7-64-k8s-master-01 kubelet[24571]: I0721 16:00:16.405867   24571 cni.go:240] "Unable to update cni config" err="no networks found in /etc/cni/net.d"
Jul 21 16:00:21 vm-centos7-64-k8s-master-01 kubelet[24571]: E0721 16:00:21.080114   24571 kubelet.go:2391] "Container runtime network not ready" networkReady="Networ...tialized"
Jul 21 16:00:21 vm-centos7-64-k8s-master-01 kubelet[24571]: I0721 16:00:21.406295   24571 cni.go:240] "Unable to update cni config" err="no networks found in /etc/cni/net.d"
Jul 21 16:00:26 vm-centos7-64-k8s-master-01 kubelet[24571]: E0721 16:00:26.088728   24571 kubelet.go:2391] "Container runtime network not ready" networkReady="Networ...tialized"
Jul 21 16:00:26 vm-centos7-64-k8s-master-01 kubelet[24571]: I0721 16:00:26.407598   24571 cni.go:240] "Unable to update cni config" err="no networks found in /etc/cni/net.d"
Hint: Some lines were ellipsized, use -l to show in full.

```
查看 k8s 集群状态
```
[root@vm-centos7-64-k8s-master-01 docker]# kubectl get cs --kubeconfig /etc/kubernetes/admin.conf
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE                         ERROR
controller-manager   Healthy   ok                              
etcd-0               Healthy   {"health":"true","reason":""}   
scheduler            Healthy   ok    
```
修改 kube-proxy configmap 启用 ipvs 模式
```
# 默认 kube-proxy 配置，此处 mode: "" 默认使用 iptable
# kubectl get configmap kube-proxy -o yaml -n kube-system --kubeconfig /etc/kubernetes/admin.conf
apiVersion: v1
data:
  config.conf: |-
    apiVersion: kubeproxy.config.k8s.io/v1alpha1
    bindAddress: 0.0.0.0
    bindAddressHardFail: false
    clientConnection:
      acceptContentTypes: ""
      burst: 0
      contentType: ""
      kubeconfig: /var/lib/kube-proxy/kubeconfig.conf
      qps: 0
    clusterCIDR: 10.244.0.0/16
    configSyncPeriod: 0s
    conntrack:
      maxPerCore: null
      min: null
      tcpCloseWaitTimeout: null
      tcpEstablishedTimeout: null
    detectLocalMode: ""
    enableProfiling: false
    healthzBindAddress: ""
    hostnameOverride: ""
    iptables:
      masqueradeAll: false
      masqueradeBit: null
      minSyncPeriod: 0s
      syncPeriod: 0s
    ipvs:
      excludeCIDRs: null
      minSyncPeriod: 0s
      scheduler: ""
      strictARP: false
      syncPeriod: 0s
      tcpFinTimeout: 0s
      tcpTimeout: 0s
      udpTimeout: 0s
    kind: KubeProxyConfiguration
    metricsBindAddress: ""
    mode: ""
    nodePortAddresses: null
    oomScoreAdj: null
    portRange: ""
    showHiddenMetricsForVersion: ""
    udpIdleTimeout: 0s
    winkernel:
      enableDSR: false
      networkName: ""
      sourceVip: ""
  kubeconfig.conf: |-
    apiVersion: v1
    kind: Config
    clusters:
    - cluster:
        certificate-authority: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        server: https://192.168.126.137:6443
      name: default
    contexts:
    - context:
        cluster: default
        namespace: default
        user: default
      name: default
    current-context: default
    users:
    - name: default
      user:
        tokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
kind: ConfigMap
metadata:
  annotations:
    kubeadm.kubernetes.io/component-config.hash: sha256:336d1586d6c1bec408739fd23aa669e69a34bd094a45f3730d3ca9a86fe3a27d
  creationTimestamp: "2022-07-21T07:50:40Z"
  labels:
    app: kube-proxy
  name: kube-proxy
  namespace: kube-system
  resourceVersion: "241"
  uid: c9825bcc-39cf-4e02-ac84-c4a7a24a9322
```
修改 mode: ipvs 启用 kube-proxy 的 ipvs 模式
```
# kubectl edit configmap kube-proxy -n kube-system --kubeconfig /etc/kubernetes/admin.conf
configmap/kube-proxy edited

# kubectl get configmap kube-proxy -o yaml -n kube-system --kubeconfig /etc/kubernetes/admin.conf|grep mode
    mode: ipvs

```

##### CNI 网络插件部署
CNI Container Network Interface，即容器网络的 API 接口，k8s 中标准的一个调用网络实现的接口。

CNI 作用主要是在创建容器时分配网络资源，和在销毁容器时删除网络资源，即给 pod 分配独立的 IP并实现相互通信。

Kubelet 通过这个标准的 API 来调用不同的网络插件以实现不同的网络配置方式，常见的 CNI 插件包括 Calico、flannel、Terway、Weave Net 以及 Contiv。

https://kubernetes.io/zh-cn/docs/concepts/cluster-administration/networking/

此处使用 flannel 作为 CNI 网络插件，flannel 基于 L3 网络层及覆盖网络(overlay network)设计，不支持 network policy。 
https://github.com/flannel-io/flannel#flannel

k8s 集群安装 flannel 插件
```
[root@vm-centos7-64-k8s-master-01 docker]# kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml --kubeconfig /etc/kubernetes/admin.conf
namespace/kube-flannel created
clusterrole.rbac.authorization.k8s.io/flannel created
clusterrolebinding.rbac.authorization.k8s.io/flannel created
serviceaccount/flannel created
configmap/kube-flannel-cfg created
daemonset.apps/kube-flannel-ds created
```
该 yaml 会创建 flannel 独立的命名空间 kube-flannel，flannel 资源类型为 daemonset，即一个 k8s 节点一个
```
[root@vm-centos7-64-k8s-master-01 docker]# kubectl get all -A --kubeconfig /etc/kubernetes/admin.conf
NAMESPACE      NAME                                                      READY   STATUS    RESTARTS   AGE
kube-flannel   pod/kube-flannel-ds-nqt7k                                 1/1     Running   0          82s
kube-system    pod/coredns-6d8c4cb4d-mmlqb                               0/1     Pending   0          78m
kube-system    pod/coredns-6d8c4cb4d-r6g6z                               0/1     Pending   0          78m
kube-system    pod/etcd-vm-centos7-64-k8s-master-01                      1/1     Running   0          78m
kube-system    pod/kube-apiserver-vm-centos7-64-k8s-master-01            1/1     Running   0          78m
kube-system    pod/kube-controller-manager-vm-centos7-64-k8s-master-01   1/1     Running   0          78m
kube-system    pod/kube-proxy-fnv9z                                      1/1     Running   0          78m
kube-system    pod/kube-scheduler-vm-centos7-64-k8s-master-01            1/1     Running   0          78m

NAMESPACE     NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
default       service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP                  78m
kube-system   service/kube-dns     ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   78m

NAMESPACE      NAME                             DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
kube-flannel   daemonset.apps/kube-flannel-ds   1         1         1       1            1           <none>                   82s
kube-system    daemonset.apps/kube-proxy        1         1         1       1            1           kubernetes.io/os=linux   78m

NAMESPACE     NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
kube-system   deployment.apps/coredns   0/2     2            0           78m

NAMESPACE     NAME                                DESIRED   CURRENT   READY   AGE
kube-system   replicaset.apps/coredns-6d8c4cb4d   2         2         0       78m

```

##### worker 节点添加
worker 节点上执行 kubeadm join 添加节点到集群中
```
[root@vm-centos7-64-k8s-worker-01 ~]# kubeadm join 192.168.126.137:6443 --token mm82pb.stvxhld7s8o49nuu \
> --discovery-token-ca-cert-hash sha256:8075d0258bbd9eb3f19fa04fdaafe29f9ee0970464b6220bd3afbcb48b222735 
[preflight] Running pre-flight checks
	[WARNING Hostname]: hostname "vm-centos7-64-k8s-worker-01" could not be reached
	[WARNING Hostname]: hostname "vm-centos7-64-k8s-worker-01": lookup vm-centos7-64-k8s-worker-01 on 8.8.8.8:53: no such host
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.

```
查看集群节点
```
[root@vm-centos7-64-k8s-master-01 docker]# kubectl get node --kubeconfig /etc/kubernetes/admin.conf
NAME                          STATUS   ROLES                  AGE    VERSION
vm-centos7-64-k8s-master-01   Ready    control-plane,master   84m    v1.23.9
vm-centos7-64-k8s-worker-01   Ready    <none>                 118s   v1.23.9


[root@vm-centos7-64-k8s-master-01 docker]# kubectl get node vm-centos7-64-k8s-worker-01 -o yaml --kubeconfig /etc/kubernetes/admin.conf
apiVersion: v1
kind: Node
metadata:
  annotations:
    flannel.alpha.coreos.com/backend-data: '{"VNI":1,"VtepMAC":"8e:80:b2:e4:bc:e5"}'
    flannel.alpha.coreos.com/backend-type: vxlan
    flannel.alpha.coreos.com/kube-subnet-manager: "true"
    flannel.alpha.coreos.com/public-ip: 192.168.126.140
    kubeadm.alpha.kubernetes.io/cri-socket: /var/run/dockershim.sock
    node.alpha.kubernetes.io/ttl: "0"
    volumes.kubernetes.io/controller-managed-attach-detach: "true"
  creationTimestamp: "2022-07-21T09:13:19Z"
  labels:
    beta.kubernetes.io/arch: amd64
    beta.kubernetes.io/os: linux
    kubernetes.io/arch: amd64
    kubernetes.io/hostname: vm-centos7-64-k8s-worker-01
    kubernetes.io/os: linux
  name: vm-centos7-64-k8s-worker-01
  resourceVersion: "6687"
  uid: 98d7c124-14b1-434a-808c-2ca1c52455f2
spec:
  podCIDR: 10.244.1.0/24
  podCIDRs:
  - 10.244.1.0/24
status:
  addresses:
  - address: 192.168.126.140
    type: InternalIP
  - address: vm-centos7-64-k8s-worker-01
    type: Hostname
  allocatable:
    cpu: "2"
    ephemeral-storage: "16415037823"
    hugepages-1Gi: "0"
    hugepages-2Mi: "0"
    memory: 3768908Ki
    pods: "110"
  capacity:
    cpu: "2"
    ephemeral-storage: 17394Mi
    hugepages-1Gi: "0"
    hugepages-2Mi: "0"
    memory: 3871308Ki
    pods: "110"
  conditions:
  - lastHeartbeatTime: "2022-07-21T09:14:00Z"
    lastTransitionTime: "2022-07-21T09:14:00Z"
    message: Flannel is running on this node
    reason: FlannelIsUp
    status: "False"
    type: NetworkUnavailable
  - lastHeartbeatTime: "2022-07-21T09:14:01Z"
    lastTransitionTime: "2022-07-21T09:12:29Z"
    message: kubelet has sufficient memory available
    reason: KubeletHasSufficientMemory
    status: "False"
    type: MemoryPressure
  - lastHeartbeatTime: "2022-07-21T09:14:01Z"
    lastTransitionTime: "2022-07-21T09:12:29Z"
    message: kubelet has no disk pressure
    reason: KubeletHasNoDiskPressure
    status: "False"
    type: DiskPressure
  - lastHeartbeatTime: "2022-07-21T09:14:01Z"
    lastTransitionTime: "2022-07-21T09:12:29Z"
    message: kubelet has sufficient PID available
    reason: KubeletHasSufficientPID
    status: "False"
    type: PIDPressure
  - lastHeartbeatTime: "2022-07-21T09:14:01Z"
    lastTransitionTime: "2022-07-21T09:14:01Z"
    message: kubelet is posting ready status
    reason: KubeletReady
    status: "True"
    type: Ready
  daemonEndpoints:
    kubeletEndpoint:
      Port: 10250
  images:
  - names:
    - registry.aliyuncs.com/google_containers/kube-proxy@sha256:ec165529c811ffe51da4f85fcc76e83ddd8a70716bed464c1aae6d85f9b4915a
    - registry.aliyuncs.com/google_containers/kube-proxy:v1.23.9
    sizeBytes: 112315538
  - names:
    - rancher/mirrored-flannelcni-flannel@sha256:b55a3b4e3dc62c4a897a2b55f60beb324ad94ee05fc6974493408ebc48d9bd77
    - rancher/mirrored-flannelcni-flannel:v0.19.0
    sizeBytes: 62278921
  - names:
    - rancher/mirrored-flannelcni-flannel-cni-plugin@sha256:28d3a6be9f450282bf42e4dad143d41da23e3d91f66f19c01ee7fd21fd17cb2b
    - rancher/mirrored-flannelcni-flannel-cni-plugin:v1.1.0
    sizeBytes: 8087907
  - names:
    - registry.aliyuncs.com/google_containers/pause@sha256:3d380ca8864549e74af4b29c10f9cb0956236dfb01c40ca076fb6c37253234db
    - registry.aliyuncs.com/google_containers/pause:3.6
    sizeBytes: 682696
  nodeInfo:
    architecture: amd64
    bootID: 6bd925d4-cb47-4fc9-a4d6-7c44980526b8
    containerRuntimeVersion: docker://19.3.5
    kernelVersion: 3.10.0-957.el7.x86_64
    kubeProxyVersion: v1.23.9
    kubeletVersion: v1.23.9
    machineID: 3de7ed13196a4b22b3de5f9a79a03ed4
    operatingSystem: linux
    osImage: CentOS Linux 7 (Core)
    systemUUID: 564D8FED-753F-FB04-72C7-BB153DDEFAFF

```




