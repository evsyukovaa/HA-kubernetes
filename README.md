# HA-kubernetes
# Multi master cluster and haproxy with hearbeat on baremetall

- Установим и настроим HAProxy с Heartbeat на первом и втором etcd -серверах (192.168.32.67–68 в этом примере):
```
k8s-etcd1# apt-get update && apt-get upgrade && apt-get install -y haproxy 
k8s-etcd2# apt-get update && apt-get upgrade && apt-get install -y haproxy
```
- Сохраним исходную конфигурацию и создадим новую на обоих серверах скопировать (config/haproxy.cfg):
```
k8s-etcd1# mv /etc/haproxy/haproxy.cfg-backup
k8s-etcd1# mcedit /etc/haproxy/haproxy.cfg
k8s-etcd2# mv /etc/haproxy/haproxy.cfg-backup
k8s-etcd2# mceidt /etc/haproxy/haproxy.cfg
```
- Так же нужно разрешить привязку системных служб к нелокальному IP-адресу добавив в sysctl.conf net.ipv4.ip_nonlocal_bind:
```
k8s-etcd1# mcedit /etc/sysctl.conf
net.ipv4.ip_nonlocal_bind=1
k8s-etcd1# sysctl -p
k8s-etcd1# systemctl start haproxy
k8s-etcd2# mcedit /etc/sysctl.conf
net.ipv4.ip_nonlocal_bind=1
k8s-etcd2# sysctl -p
k8s-etcd2# systemctl start haproxy
```
- Проверить что haproxy запущен
```
k8s-etcd1# netstat -ntlp
tcp 0 0 192.168.32.66:6443 0.0.0.0:* LISTEN 2833/haproxy
k8s-etcd2# netstat -ntlp
tcp 0 0 192.168.32.66:6443 0.0.0.0:* LISTEN 2833/haproxy
```
- Установим Heartbeat и настроим его на этот виртуальный IP
```
k8s-etcd1# apt-get -y install heartbeat && systemctl enable heartbeat
k8s-etcd2# apt-get -y install heartbeat && systemctl enable heartbeat
```
- Создадим файл /etc/ha.d/authkeys, в этом файле Heartbeat хранит данные для взаимной аутентификации. Файл должен быть одинаковым на обоих серверах:
```
echo -n securepass | md5sum
bb77d0d3b3f239fa5db73bdf27b8d29a
k8s-etcd1# vi /etc/ha.d/authkeys
auth 1
1 md5 bb77d0d3b3f239fa5db73bdf27b8d29a
k8s-etcd1# chmod 600 /etc/ha.d/authkeys
k8s-etcd2# vi /etc/ha.d/authkeys
auth 1
1 md5 bb77d0d3b3f239fa5db73bdf27b8d29a
k8s-etcd2# chmod 600 /etc/ha.d/authkeys
```
- Создадим основной файл конфигурации для Heartbeat на обоих серверах: для каждого сервера он будет немного отличаться./etc/ha.d/ha.cf (сonfig/ha.cf-etcd*):
- Теперь нужно создать на этих серверах файл /etc/ha.d/haresources. Для обоих серверов файл должен быть одинаковым. В этом файле мы задаем наш общий IP-адрес и определяем, какая нода является главной по умолчанию (config/haresources)
- Когда все готово, запускаем службы Heartbeat на обоих серверах и проверяем, что на ноде k8s-etcd1 мы получили этот заявленный виртуальный IP:
```
k8s-etcd1# systemctl restart heartbeat
k8s-etcd2# systemctl restart heartbeat
k8s-etcd1# ip a
enp1s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 52:54:00:03:a0:d0 brd ff:ff:ff:ff:ff:ff
    inet 192.168.32.67/24 brd 192.168.32.255 scope global dynamic enp1s0
       valid_lft 5718sec preferred_lft 5718sec
    inet 192.168.32.66/24 brd 192.168.32.255 scope global secondary enp1s0:0
```
- Уже предпологается что установлены docker,kubeadm,kubelet,kubectl (готовые лежат на as4:/backup/images/k8s-clean)
- На всех etcd нодах нужно добавить новый файл конфигурации systemd для юнита kubelet с более высоким приоритетом:
```
- cat << EOF > /etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf
[Service]
ExecStart=
ExecStart=/usr/bin/kubelet --address=127.0.0.1 --pod-manifest-path=/etc/kubernetes/manifests
Restart=always
EOF
```
- Заходим на k8s-etcd1 (предварительно должны быть настроены ssh ключи между серверами) и выполняем скрипт (scripts/etcd-cluster.sh)
- После выполнения скрипта перезапустим kubelet на всех нодах etcd
```
systemctl restart kubelet
```
-Проверить что класетр рабочий командой:
```
k8s-etcd1# etcdctl endpoint status --cert="/etc/kubernetes/pki/etcd/peer.crt" --key="/etc/kubernetes/pki/etcd/peer.key" --cacert="/etc/kubernetes/pki/etcd/ca.crt" --endpoints=https://192.168.32.67:2379 -w table
52bc66b324ada68, started, k8s-etcd2, https://192.168.32.68:2380, https://192.168.32.68:2379, false
5342bb862fda1a8, started, k8s-etcd3, https://192.168.32.69:2380, https://192.168.32.69:2379, false
41d21d5686477304, started, k8s-etcd1, https://192.168.32.67:2380, https://192.168.32.67:2379, false

k8s-etcd1# etcdctl --cert="/etc/kubernetes/pki/etcd/peer.crt" --key="/etc/kubernetes/pki/etcd/peer.key" --cacert="/etc/kubernetes/pki/etcd/ca.crt" --endpoints=https://192.168.32.67:2379 member list
+----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|          ENDPOINT          |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://192.168.32.67:2379 | 41d21d5686477304 |   3.4.3 |   20 kB |      true |      false |         8 |        239 |                239 |        |
+----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```
- Настраиваем мастер ноды, на первой масетре ноде k8s-master1 запустим скрипт scripts/master-cluster.sh
- Скрипт создаст конфиг, скопирует все необходимы ключи, инициализирует масетр ноду, и запишет токен который понадобится для подключения второй мастер ноды в /root/init-cluster-tocken, так же скопирует все необходимы ключи и на k8s-master2.
- После выполнения скрипта, проверяем что мастер нода поднялась
```
k8s-master1# kubectl get po -n kube-system
NAME                                  READY   STATUS    RESTARTS   AGE
coredns-66bff467f8-5kfdd              1/1     Running   1          33m
coredns-66bff467f8-fj9sv              1/1     Running   1          33m
kube-apiserver-k8s-master1            1/1     Running   2          33m
kube-apiserver-k8s-master2            1/1     Running   0          110s
kube-controller-manager-k8s-master1   1/1     Running   2          33m
kube-controller-manager-k8s-master2   1/1     Running   0          109s
kube-proxy-84pzk                      1/1     Running   0          111s
kube-proxy-8dvd8                      1/1     Running   2          33m
kube-scheduler-k8s-master1            1/1     Running   2          33m
kube-scheduler-k8s-master2            1/1     Running   0          109s
weave-net-dq9sp                       2/2     Running   5          30m
weave-net-g2lg4                       2/2     Running   0          111s

k8s-master1# kubectl get nodes
NAME          STATUS   ROLES    AGE   VERSION
k8s-master1   Ready    master   82m   v1.18.2
```
- Если все хорошо то присоединяем вторую мастер ноду к кластеру токен и sha берем из /root/init-cluster-tocken на первой мастре ноду, и ОБЯЗАТЕЛЬНО ключ --control-plane без него будет просто worker нода добавлена
```
k8s-master2# kubeadm join 192.168.32.66:6443 --control-plane --token tocke_key --discovery-token-ca-cert-hash sha256:tocken_sha
```
- Теперь подключим все рабочие ноды, запустим туже команду что и выше, только без ключа --control-plane
```
k8s-worker1-3# kubeadm join 192.168.32.66:6443 --token tocke_key --discovery-token-ca-cert-hash sha256:tocken_sha
```
- Проверяем что все подключились:
```
kubectl get nodes
NAME          STATUS   ROLES    AGE   VERSION
k8s-master1   Ready    master   82m   v1.18.2
k8s-master2   Ready    master   50m   v1.18.2
k8s-worker1   Ready    worker   41m   v1.18.2
k8s-worker2   Ready    worker   41m   v1.18.2
k8s-worker3   Ready    worker   40m   v1.18.2
```
- У нас есть полностью настроенный HA-кластер Kubernetes с двумя мастер- и тремя рабочими нодами. Он построен на основе кластера HA etcd с отказоустойчивым балансировщиком нагрузки перед мастер-нодами
