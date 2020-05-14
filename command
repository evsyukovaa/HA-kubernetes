####
etcdctl endpoint status --cert="/etc/kubernetes/pki/etcd/peer.crt" --key="/etc/kubernetes/pki/etcd/peer.key" --cacert="/etc/kubernetes/pki/etcd/ca.crt" --endpoints=https://192.168.32.67:2379 -w table
etcdctl --cert="/etc/kubernetes/pki/etcd/peer.crt" --key="/etc/kubernetes/pki/etcd/peer.key" --cacert="/etc/kubernetes/pki/etcd/ca.crt" --endpoints=https://192.168.32.67:2379 member list
kubeadm join 192.168.32.66:6443 --control-plane --token tocke_key --discovery-token-ca-cert-hash sha256:tocken_sha
####
