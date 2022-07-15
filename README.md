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



### 插件
- CRI
  - docker 
  
- CNI
  - flannel
  - calico
  - canal
  - terway
- CSI
  - ceph
  - glusterfs
  - nas





