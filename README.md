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
