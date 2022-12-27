# Описание скрипта
## docker.sh

Скрипт позволяет устанавливать docker, docker-compose и выставлять дефолтный пул адресов для подсетей - вновь созданных контейнеров

Начиная с версии 18.09.1, появилась возможность использовать выдачу подсетей по дефолту для вновь созданных контейнеров.

Выглядит это вот  так:
```
 "default-address-pools" : [
    {
      "base" : "172.200.0.0/16",
      "size" : 24
    }
  ]
```
Т.е. для каждого нового композа, при условии что сеть в нём не указана (дефолтная), сеть будет создаваться вида 172.200.*.0/24.
Запущенные же контейнеры командой docker run будут попадать в нулевую сеть 172.200.0.0/24.

После запуска скрипт:

1. Уставнливает docker и docker-compose
2. проверяет наличие файла конфигурации докера, создаёт если отсутствует. Если файл уже есть, делает копию в /etc/docker/;
3. применяет настройки докера путём перезапуска сокета;
4. тестирует, получил ли контейнер редиса, запущенный через docker-compose правильный адрес. (edited)

## Инструкция по применению: 
1. склонировать репозиторий;
2. сделать sudo chmod +x docker.sh;
3. запустить скрипт;
4. при необходимости, возможно открыть socket TCP port 2375

## Enable TCP port 2375 for external connection to Docker
------------------------------------------------------

1. Change `daemon.json` file in `/etc/docker`:
```
{"hosts": ["tcp://0.0.0.0:2375", "unix:///var/run/docker.sock"],
 "default-address-pools" : [
   {
    "base" : "172.200.0.0/16",
    "size" : 24
   }
  ],
 "data-root": "/mnt/docker" # Change mount
}
```
2. Add `/etc/systemd/system/docker.service.d/override.conf`
```
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd
```

3. Reload the systemd daemon:
```
systemctl daemon-reload
```
4. Restart docker:
```
systemctl restart docker.service
```
5. Check on another host
```
docker -H tcp://xxx.xxx.x.xx:2375 ps
```
## Deckhouse - worker node on Ubuntu 22.04 base image with docker
------------------------------------------------------
P.s if you have a node on Ubuntu 22.04 and you want to use docker with volumes forwarding. Then see below.

```
systemctl stop kubelet
```
```
mkdir -p /etc/systemd/system/docker.service.d/
```
```
tee /etc/systemd/system/docker.service.d/docker.conf <<"EOF"
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock --default-cgroupns-mode=host
EOF
```
or without daemon.json
```
tee /etc/systemd/system/docker.service.d/docker.conf <<"EOF"
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock --default-cgroupns-mode=host --exec-opt native.cgroupdriver=cgroupfs
EOF
```
```
sudo systemctl daemon-reload && systemctl restart docker && systemctl restart kubelet
```

## P.s Изначальный создатель скрипта

@eberil

## Скрипт обновляется и поддерживается

@izobretatel9
