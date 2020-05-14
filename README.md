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



