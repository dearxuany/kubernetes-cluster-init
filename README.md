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

| host | ip              | cpu | ram | dish |   system   |   |   |
|------|-----------------|-----|-----|------|------------|---|---|
|      | 192.168.126.137 | 4   | 4GB | 20GB | centos7 64 |   |   |
|      |    |     |     |      | centos7 64 |   |   |
|      |    |     |     |      | centos7 64 |   |   |
|      |    |     |     |      |            |   |   |
|      |    |     |     |      |            |   |   |
|      |    |     |     |      |            |   |   |


### VM 虚拟机初始配置
详细配置见 [vmware 虚拟机初始配置](docs/vmware-host-init.md)



