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


### 插件
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

| host                      | ip              | cpu | ram | dish |   system   |   |   |
|---------------------------|-----------------|-----|-----|------|------------|---|---|
|vm-centos7-64-k8s-master-01| 192.168.126.137 | 4   | 4GB | 20GB | centos7 64 |   |   |
|vm-centos7-64-k8s-master-02| 192.168.126.138 |     |     |      | centos7 64 |   |   |
|vm-centos7-64-k8s-master-03| 192.168.126.139 |     |     |      | centos7 64 |   |   |
|vm-centos7-64-k8s-node-01  | 192.168.126.140 |     |     |      |            |   |   |
|vm-centos7-64-k8s-node-02  | 192.168.126.141 |     |     |      |            |   |   |



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
启用确认
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



