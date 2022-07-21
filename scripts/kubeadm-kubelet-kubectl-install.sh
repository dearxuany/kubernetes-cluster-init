#! /bin/bash

# check versions
yum list kubelet kubeadm kubectl  --showduplicates|sort -r|grep 1.23


yum install -y kubelet-1.23.9 kubeadm-1.23.9 kubectl-1.23.9 --disableexcludes=kubernetes

sleep 10

sudo systemctl enable --now kubelet && systemctl start kubelet

kubeadm version
kubectl version --client
kubelet --version

