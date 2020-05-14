#!/bin/bash

###########################################
#Скрипт выполнять на первой мастер ноде k8s-master1
###########################################

###Create kubeadm-config for initialization cluster
cat << EOF > /root/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
kubernetesVersion: stable
apiServer:
  certSANs:
  - "192.168.32.66"
controlPlaneEndpoint: "192.168.32.66:6443"
etcd:
    external:
        endpoints:
        - https://192.168.32.67:2379
        - https://192.168.32.68:2379
        - https://192.168.32.69:2379
        caFile: /etc/kubernetes/pki/etcd/ca.crt
        certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
        keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key
EOF

###Copy certificates copy from etcd1
mkdir -p /etc/kubernetes/pki/etcd/
cp /root/ca.crt /etc/kubernetes/pki/etcd/
cp /root/apiserver-etcd-client.* /etc/kubernetes/pki/

###initialization first master1
kubeadm init --config kubeadm-config.yaml >> /root/init-cluster-tocken
sleep 5m
echo Wait initialization master node 5 min
cp /etc/kubernetes/admin.conf /root/.kube/config
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
echo Wait running pod and initialization master node: kubectl pod get pod -n kube-system -w && kubectl get nodes
sleep 1m

###Copy certificates on master2
scp /etc/kubernetes/pki/ca.crt 192.168.32.71:
scp /etc/kubernetes/pki/ca.key 192.168.32.71:
scp /etc/kubernetes/pki/sa.key 192.168.32.71:
scp /etc/kubernetes/pki/sa.pub 192.168.32.71:
scp /etc/kubernetes/pki/front-proxy-ca.crt 192.168.32.71:
scp /etc/kubernetes/pki/front-proxy-ca.key 192.168.32.71:
scp /etc/kubernetes/pki/apiserver-etcd-client.crt 192.168.32.71:
scp /etc/kubernetes/pki/apiserver-etcd-client.key 192.168.32.71:
scp /etc/kubernetes/pki/etcd/ca.crt 192.168.32.71:etcd-ca.crt
scp /etc/kubernetes/admin.conf 192.168.32.71:

###mv certificates on master2
ssh root@k8s-master2 'mkdir -p /etc/kubernetes/pki/etcd'
ssh root@k8s-master2 'mv /root/ca.crt /etc/kubernetes/pki/'
ssh root@k8s-master2 'mv /root/ca.key /etc/kubernetes/pki/'
ssh root@k8s-master2 'mv /root/sa.pub /etc/kubernetes/pki/'
ssh root@k8s-master2 'mv /root/sa.key /etc/kubernetes/pki/'
ssh root@k8s-master2 'mv /root/apiserver-etcd-client.crt /etc/kubernetes/pki/'
ssh root@k8s-master2 'mv /root/apiserver-etcd-client.key /etc/kubernetes/pki/'
ssh root@k8s-master2 'mv /root/front-proxy-ca.crt /etc/kubernetes/pki/'
ssh root@k8s-master2 'mv /root/front-proxy-ca.key /etc/kubernetes/pki/'
ssh root@k8s-master2 'mv /root/etcd-ca.crt /etc/kubernetes/pki/etcd/ca.crt'
ssh root@k8s-master2 'mv /root/admin.conf /etc/kubernetes/admin.conf'
