#!/bin/bash
#by @eberil
#CHANGED by @izobretatel9

#who run script?
RUN_USER=$(export | grep SUDO_USER | sed 's/declare\|-\|x\|SUDO_USER\|=\|"\| //g')
echo -e "\e[33mHello \e[0m\e[1m$RUN_USER'!\e[0m"
echo ""

#lets go
docker version > /dev/null 2>&1

if [ $? -eq 0 ]
then
  echo -e "\e[32m Check for new version of docker ...\e[0m"
  CURRENT_VER_CLIENT=$(docker version | grep Version | awk {'print $2'} | head -n 1)
  CURRENT_VER_ENGINE=$(docker engine check | grep current | awk {'print $2'})
else
  CHECK_CURRENT_VER=0
  echo -e "\e[33m Docker not found" >&2
fi

#Uninstall old unsupported version
echo -e "\e[33m Uninstalling old unsupported version ...\e[0m"
apt-get -y remove docker docker-engine docker.io containerd runc && \
    apt -y autoremove

if [ $? -eq 0 ]
then
  echo -e "\e[33m Old unsupported version has been removed or not installed\e[0m"
else
  CHECK_CURRENT_VER=0
  echo -e "\e[33m Old version not found. Nothing to do.\e[0m" >&2
fi

#Install requiement prerequisites and install docker
echo -e "\e[32m Install requiement prerequisites for docker stack and install docker ce...\e[0m"

apt-get update && \
    apt-get -y install apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    software-properties-common && \
    curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg > /tmp/dkey; apt-key add /tmp/dkey && \
    add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
    $(lsb_release -cs) \
    stable" && \
    apt-get update && \
    apt-get -y install docker-ce docker-ce-cli containerd.io

if [ $? -eq 0 ]
then
  NEW_VER_CLIENT=$(docker version | grep Version | awk {'print $2'} | head -n 1)
  NEW_VER_ENGINE=$(docker engine check | grep current | awk {'print $2'})

  if [ $NEW_VER_CLIENT == $CURRENT_VER_CLIENT ] && [ $NEW_VER_ENGINE == $CURRENT_VER_ENGINE ]
  then
    echo -e "\e[32m Docker stack up-to-date!\e[0m"
  else
    echo -e "\e[32m Docker \e[0m\e[1mdocker-ce docker-ce-cli containerd.io \e[32msuccesfully installed\e[0m"
    echo -e "\e[33m Client version changed from \e[0m\e[1m'$CURRENT_VER_CLIENT' \e[0mto \e[0m\e[1m'$NEW_VER_CLIENT'\e[0m"
    echo -e "\e[33m Version of Docker-Engine changed from \e[0m\e[1m'$CURRENT_VER_ENGINE'\e[0mto \e[0m\e[1m'$NEW_VER_ENGINE' \e[0m"
  fi

else
  echo -e "\e[31m Failed to install \e[0m\e[1mdocker-ce docker-ce-cli containerd.io\e[0m" >&2
fi

#run Hello-World container
docker run hello-world

if [ $? -eq 0 ]
then
  echo -e "\e[32m Docker ready to work!\e[0m"
  echo -e "\e[33m Clean up ...\e[0m"
  docker rm -v $(docker ps -aq -f status=exited)
  echo -e "\e[32m Done.\e[0m"
else
  echo -e "\e[31m Failed to run \e[0m\e[1m"Hello World" \e[31from container\e[0m" >&2
  echo -e "\e[33m Please, try to reistall docker stack\e[0m"
fi

#lets go
docker-compose version > /dev/null 2>&1

#check for new version
if [ $? -eq 0 ]
then
  echo -e "\e[33m Check for new version of docker-compose ...\e[0m"
  CHECK_CURRENT_VER=$(docker-compose version | grep docker-compose | awk {'print $3'} | sed 's/,//g')
else
  CHECK_CURRENT_VER=0
  echo -e "\e[33m Docker-compose not Found\e[0m" >&2
fi

RELEASE_URL=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/docker/compose/releases/latest)
CHECK_NEW_VER="${RELEASE_URL##*/}"

if [ $CHECK_CURRENT_VER == $CHECK_NEW_VER ]
then
    echo -e "\e[32mVersion of docker-compose up-to-date!\e[0m"
else
    echo -e "\e[33m Found new version of docker-compose '$CHECH_CURRENT_VER'\e[0m"
fi

#download binaries
DOWNLOAD_URL=$(curl -L "https://github.com/docker/compose/releases/download/$CHECK_NEW_VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose)

$DOWNLOAD_URL

if [ $? -eq 0 ]
then
  BINDIR="/usr/local/bin/docker-compose"
  chmod +x $BINDIR
  echo -e "\e[32m Istallation of docker-compose complete!\e[0m"
  echo -e "\e[32m Version of docker-compose was changed from \e[0m\e[1m'$CHECK_CURRENT_VER' \e[31mto \e[0m\e[1m'$CHECK_NEW_VER'\e[0m"
else
  echo -e "\e[31m Failed to install docker-compose '$CHECK_NEW_VER' \e[31mto \e[0m\e[1m'/usr/local/bin/docker-compose'\e[0m" >&2
fi

#create file
DOCKER_PATH=/etc/docker
echo -e "\e[33m Creating daemon.json ...\e[0m"

sudo cat /etc/docker/daemon.json > /dev/null 2>&1

if [ $? -eq 0 ]
then
  echo -e "\e[32m daemon.json founded. Copy backup to /etc/docker/daemon.json.backup..\e[0m"
  sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup
  sudo rm /etc/docker/daemon.json
  echo -e "\e[33m Please add setting from backup in to daemon.json after installation.\e[0m"
else
  echo -e "\e[33m daemon.json not found. Creating...\e[0m" >&2
fi

#copy settings to daemon.json
echo -e "\e[33m Create and Copy settings to daemon.json ...\e[0m"

echo -e '{\n "default-address-pools" : [\n {\n  "base" : "172.200.0.0/16",\n  "size" : 24\n  }\n ]\n }' | tee $DOCKER_PATH/daemon.json > /dev/n$
echo -e 'version: "2.4"\nservices:\n redis:\n  image: library/redis:6-alpine\n  container_name: redis' | tee $DOCKER_PATH/test.yml > /dev/null $


if [ $? -eq 0 ]
then
  echo -e "\e[32m Done.\e[0m"
else
  echo -e "\e[31m Copy failed! Abort\e[0m" >&2
fi

#restart docker
echo -e "\e[33m Apply settings ...\e[0m"

sudo systemctl restart docker

if [ $? -eq 0 ]
then
  echo -e "\e[32m Done.\e[0m"
else
  echo -e "\e[31m Daemon of docker can't been reload. Please, see docker logs, to fix problem\e[0m" >&2
fi

#healthcheck
echo -e "\e[33m Checking ip-address with redis ...\e[0m"

cd $DOCKER_PATH
sudo docker-compose -f test.yml up -d

if [ $? -eq 0 ]

then
  IP_ADDRESS=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' redis | cut -c 1-8)
  echo $IP_ADDRESS

  if [ $IP_ADDRESS == "172.200." ]

  then
     sudo docker-compose -f test.yml down && docker rmi redis:6-alpine --force
     echo "
██████████████████████████████████████████████████████████████████████████████████████████████
█▄─█─▄██▀▄─██▄─▄▄▀█▄─▄█▄─▀█▀─▄█▄─▄█░▄▄░▄█─▄▄─█▄─▄─▀█▄─▄▄▀█▄─▄▄─█─▄─▄─██▀▄─██─▄─▄─█▄─▄▄─█▄─▄███
██▄▀▄███─▀─███─██─██─███─█▄█─███─███▀▄█▀█─██─██─▄─▀██─▄─▄██─▄█▀███─████─▀─████─████─▄█▀██─██▀█
▀▀▀▄▀▀▀▄▄▀▄▄▀▄▄▄▄▀▀▄▄▄▀▄▄▄▀▄▄▄▀▄▄▄▀▄▄▄▄▄▀▄▄▄▄▀▄▄▄▄▀▀▄▄▀▄▄▀▄▄▄▄▄▀▀▄▄▄▀▀▄▄▀▄▄▀▀▄▄▄▀▀▄▄▄▄▄▀▄▄▄▄▄▀
"
     echo -e "\e[33m Don't forget copy data from daemon.json, if its necessary\e[0m"
     exit 0
  else
     echo -e "\e[31m IP-address not equal 172.200.*.*/24 . Removing redis\e[0m" >&2
     sudo docker-compose -f test.yml down
  exit 1

  fi

else
  echo -e "\e[31m Something wrone with redis. Try again. Remove redis..\e[0m" >&2
  sudo docker-compose -f test.yml down
  exit 1

fi
