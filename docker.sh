#!/bin/bash
#by @izobretatel9

RUN_USER=$(export | grep SUDO_USER | awk -F '=' '{print $2}' | tr -d '"')
echo -e "\033[33mHello \033[0m\033[1m'$RUN_USER'!\033[0m"
echo ""

# Check for docker version
if docker version > /dev/null 2>&1; then
  echo -e "\e[32m Check for new version of docker ...\e[0m"
  CURRENT_VER_CLIENT=$(docker -v | awk '{print $3}' | tr -d ',')
  CURRENT_VER_ENGINE=$(docker engine -v | awk '{print $3}' | tr -d ',')
else
  CURRENT_VER_CLIENT=0
  CURRENT_VER_ENGINE=0
  echo -e "\e[31m Docker not found\e[0m" >&2
fi

#Uninstall old unsupported version
echo -e "\e[33m Uninstalling old unsupported version ...\e[0m"
if apt-get remove docker docker-engine docker.io containerd runc && \
  apt -y autoremove; then
  echo -e "\e[33m Old unsupported version has been removed or not installed\e[0m"
else
  echo -e "\e[33m Old version not found. Nothing to do.\e[0m" >&2
fi

# Installing required prerequisites and Docker CE

echo -e "\e[32m Installing prerequisites and Docker...\e[0m"

apt update -y && \
  apt-get -y install apt-transport-https ca-certificates curl gnupg2 software-properties-common && \
  curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | apt-key add - && \
  add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") $(lsb_release -cs) stable" && \
  apt update && \
  apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin

if [ $? -eq 0 ]; then
  NEW_VER_CLIENT=$(docker -v | awk '{print $3}' | tr -d ',')
  NEW_VER_ENGINE=$(docker engine -v | awk '{print $3}' | tr -d ',')
  echo -e "\e[32m Docker \e[0m\e[1mdocker-ce docker-ce-cli containerd.io \e[32msuccesfully installed\e[0m"
  echo -e "\e[32m Docker client version changed from \e[0m\e[33m'$CURRENT_VER_CLIENT'\e[32m to '$NEW_VER_CLIENT'\e[0m"
  echo -e "\e[32m Docker server version changed from \e[0m\e[33m'$CURRENT_VER_ENGINE'\e[32m to '$NEW_VER_ENGINE'\e[0m"
else
  echo -e "\e[31m Failed to install Docker\e[0m" >&2
fi

# Run Hello-World container
if docker run hello-world &> /dev/null; then
  echo -e "\e[32m Docker ready to work!\e[0m"
  echo -e "\e[33m Clean up ...\e[0m"
  docker rm -v $(docker ps -aq -f status=exited) &> /dev/null
  echo -e "\e[32m Done.\e[0m"
else
  echo -e "\e[31m Failed to run \e[0m\e[1m"Hello World" \e[31from container\e[0m" >&2
  echo -e "\e[33m Please, try to reistall docker stack\e[0m"
fi

# check for docker-compose
if command -v docker-compose > /dev/null 2>&1; then
  echo -e "\e[33m Checking for a new version of docker-compose ...\e[0m"
  CHECK_CURRENT_VER=$(docker-compose version | awk '{print $4}')
else
  echo -e "\e[31m Docker-compose not found\e[0m" >&2
  CHECK_CURRENT_VER=0
fi

# get the latest version number
RELEASE_URL=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/docker/compose/releases/latest)
CHECK_NEW_VER="${RELEASE_URL##*/}"

# compare version numbers
if [ "$CHECK_CURRENT_VER" == "$CHECK_NEW_VER" ]; then
    echo -e "\e[32m Docker-compose is up-to-date\e[0m"
else
    echo -e "\e[33m New version of docker-compose found:\e[32m'$CHECK_NEW_VER'\e[0m"
    # download and install the latest version
    DOWNLOAD_URL=$(curl -L "https://github.com/docker/compose/releases/download/$CHECK_NEW_VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose)
    if [ $? -eq 0 ]; then
      chmod +x /usr/local/bin/docker-compose
      echo -e "\e[32m Docker-compose was installed successfully\e[0m"
      echo -e "\e[32m Version changed from \e[33m'$CHECK_CURRENT_VER'\e[32m to '$CHECK_NEW_VER'\e[0m"
    else
      echo -e "\e[31m Failed to install docker-compose '$CHECK_NEW_VER' to '/usr/local/bin/docker-compose'\e[0m" >&2
    fi
fi

#copy settings to daemon.json

mkdir -p /etc/docker
DOCKER_PATH=/etc/docker
sudo cat $DOCKER_PATH/daemon.json > /dev/null 2>&1

if [ $? -eq 0 ]
then
  echo -e "\e[32m daemon.json founded. Copy backup to /etc/docker/daemon.json.backup..\e[0m"
  sudo cp $DOCKER_PATH/daemon.json $DOCKER_PATH/daemon.json.backup
  sudo rm $DOCKER_PATH/daemon.json
  echo -e "\e[33m Please add setting from backup in to daemon.json after installation.\e[0m"
else
  echo -e "\e[33m daemon.json not found. Creating...\e[0m" >&2
fi

echo -e "\e[33m Create and Copy settings to daemon.json ...\e[0m"
cat << EOF > "$DOCKER_PATH/daemon.json"
{
 "default-address-pools" : [
  {
   "base" : "172.200.0.0/16",
   "size" : 24
   }
 ],
 "registry-mirrors": [
  "https://dockerhub1.beget.com",
  "https://mirror.gcr.io"
 ]
}
EOF

cat << EOF > "$DOCKER_PATH/test.yml"
services:
 redis:
  image: library/redis:6-alpine
  container_name: redis
EOF

if [ $? -eq 0 ]
then
  echo -e "\e[32m Done.\e[0m"
else
  echo -e "\e[31m Copy failed! Abort\e[0m" >&2
  exit 1
fi

#restart docker
echo -e "\e[33m Apply settings ...\e[0m"
sudo systemctl restart docker

if [ $? -eq 0 ]
then
  echo -e "\e[32m Done.\e[0m"
else
  echo -e "\e[31m Daemon of docker can't been reload. Please, see docker logs, to fix problem\e[0m" >&2
  exit 1
fi

#healthcheck
echo -e "\e[33m Checking ip-address with redis ...\e[0m"
cd "$DOCKER_PATH"
sudo docker-compose -f test.yml up -d

if [ $? -eq 0 ]
then
  IP_ADDRESS=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' redis | awk -F . '{print $1"."$2}')
  echo $IP_ADDRESS

  if [ "$IP_ADDRESS" == "172.200" ]
  then
     sudo docker-compose -f test.yml down && docker rmi redis:6-alpine --force
     echo "
██████████████████████████████████████████████████████████████████████████████████████████████
█▄─█─▄██▀▄─██▄─▄▄▀█▄─▄█▄─▀█▀─▄█▄─▄█░▄▄░▄█─▄▄─█▄─▄─▀█▄─▄▄▀█▄─▄▄─█─▄─▄─██▀▄─██─▄─▄─█▄─▄▄─█▄─▄███
██▄▀▄███─▀─███─██─██─███─█▄█─███─███▀▄█▀█─██─██─▄─▀██─▄─▄██─▄█▀███─████─▀─████─████─▄█▀██─██▀█
▀▀▀▄▀▀▀▄▄▀▄▄▀▄▄▄▄▀▀▄▄▄▀▄▄▄▀▄▄▄▀▄▄▄▀▄▄▄▄▄▀▄▄▄▄▀▄▄▄▄▀▀▄▄▀▄▄▀▄▄▄▄▄▀▀▄▄▄▀▀▄▄▀▄▄▀▀▄▄▄▀▀▄▄▄▄▄▀▄▄▄▄▄▀
"
     echo -e "\e[33m Don't forget copy data from daemon.json.backup, if its necessary\e[0m"
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
