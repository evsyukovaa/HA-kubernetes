#!/bin/bash

##############################################
#Скрипт выполнять на первой ноде etcd1
#предварительно настроив безпарольный доступ по ssh
#пользователю с полными правами на etcd2,etcd2,master1,master2
##############################################

export HOST0=192.168.32.67
export HOST1=192.168.32.68
export HOST2=192.168.32.69

# Create temp directories to store files for all nodes
mkdir -p /tmp/${HOST0}/ /tmp/${HOST1}/ /tmp/${HOST2}/

ETCDHOSTS=(${HOST0} ${HOST1} ${HOST2})
NAMES=("k8s-etcd1" "k8s-etcd2" "k8s-etcd3")

for i in "${!ETCDHOSTS[@]}"; do
HOST=${ETCDHOSTS[$i]}
NAME=${NAMES[$i]}
cat << EOF > /tmp/${HOST}/kubeadmcfg.yaml
apiVersion: "kubeadm.k8s.io/v1beta1"
kind: ClusterConfiguration
etcd:
    local:
        serverCertSANs:
        - "${HOST}"
        peerCertSANs:
        - "${HOST}"
        extraArgs:
            initial-cluster: ${NAMES[0]}=https://${ETCDHOSTS[0]}:2380,${NAMES[1]}=https://${ETCDHOSTS[1]}:2380,${NAMES[2]}=https://${ETCDHOSTS[2]}:2380
            initial-cluster-state: new
            name: ${NAME}
            listen-peer-urls: https://${HOST}:2380
            listen-client-urls: https://${HOST}:2379
            advertise-client-urls: https://${HOST}:2379
            initial-advertise-peer-urls: https://${HOST}:2380
EOF
done

### Create certificates for the etcd3 node
kubeadm init phase certs etcd-ca
kubeadm init phase certs etcd-server --config=/tmp/${HOST2}/kubeadmcfg.yaml
kubeadm init phase certs etcd-peer --config=/tmp/${HOST2}/kubeadmcfg.yaml
kubeadm init phase certs etcd-healthcheck-client --config=/tmp/${HOST2}/kubeadmcfg.yaml
kubeadm init phase certs apiserver-etcd-client --config=/tmp/${HOST2}/kubeadmcfg.yaml
cp -R /etc/kubernetes/pki /tmp/${HOST2}/

### cleanup non-reusable certificates
find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete

### Create certificates for the etcd2 node
kubeadm init phase certs etcd-server --config=/tmp/${HOST1}/kubeadmcfg.yaml
kubeadm init phase certs etcd-peer --config=/tmp/${HOST1}/kubeadmcfg.yaml
kubeadm init phase certs etcd-healthcheck-client --config=/tmp/${HOST1}/kubeadmcfg.yaml
kubeadm init phase certs apiserver-etcd-client --config=/tmp/${HOST1}/kubeadmcfg.yaml
cp -R /etc/kubernetes/pki /tmp/${HOST1}/

### cleanup non-reusable certificates again
find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete

### Create certificates for the this local node
kubeadm init phase certs etcd-server --config=/tmp/${HOST0}/kubeadmcfg.yaml
kubeadm init phase certs etcd-peer --config=/tmp/${HOST0}/kubeadmcfg.yaml
kubeadm init phase certs etcd-healthcheck-client --config=/tmp/${HOST0}/kubeadmcfg.yaml
kubeadm init phase certs apiserver-etcd-client --config=/tmp/${HOST0}/kubeadmcfg.yaml

#No need to move the certs because they are for this node
# clean up certs that should not be copied off this host
find /tmp/${HOST2} -name ca.key -type f -delete
find /tmp/${HOST1} -name ca.key -type f -delete

###copy certificates on node
scp -r /tmp/${HOST1}/* ${HOST1}:
scp -r /tmp/${HOST2}/* ${HOST2}:

### login to the etcd2 or run this command remotely by ssh
ssh root@k8s-etcd2 'mv /root/pki /etc/kubernetes/'
### login to the etcd3 or run this command remotely by ssh
ssh root@k8s-etcd3 'mv /root/pki /etc/kubernetes/'

###create manifest file etcd on etcd1
kubeadm init phase etcd local --config=/tmp/192.168.32.67/kubeadmcfg.yaml

###create manifest file etcd on etcd2
ssh root@k8s-etcd2 'kubeadm init phase etcd local --config=/root/kubeadmcfg.yaml'

###create manifest file etcd on etcd3
ssh root@k8s-etcd3 'kubeadm init phase etcd local --config=/root/kubeadmcfg.yaml'

###copy certificates on master1
scp /etc/kubernetes/pki/etcd/ca.crt 192.168.32.70:
scp /etc/kubernetes/pki/apiserver-etcd-client.* 192.168.32.70:
