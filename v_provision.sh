#!/bin/bash

mkdir .dist
cd .dist
HDIR="/home/vagrant"
APPDIR="${HDIR}/go/src/github.com/chainHero/heroes-service"

DEBIAN_FRONTEND=noninteractive 

# Step: Installing Docker
sudo apt -qq update
sudo apt install -qq -y apt-transport-https ca-certificates curl software-properties-common make g++ gcc git protobuf-compiler
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - 
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"  -y
sudo apt -qq update
sudo apt install -qq -y docker-ce
sudo chmod 777 /var/run/docker.sock
sudo groupadd docker 
sudo gpasswd -a ${USER} docker
sudo service docker restart
docker -v

# Step: Installing Docker Compose
sudo curl -sL "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose version

# Step: Installing Go
wget -nv https://storage.googleapis.com/golang/go1.14.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.14.linux-amd64.tar.gz
rm go1.14.linux-amd64.tar.gz
sudo chown -R vagrant "$HDIR/go"
echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee -a /etc/profile
echo 'export GOPATH=$HOME/go' | tee -a $HDIR/.bashrc
echo 'export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' | tee -a $HDIR/.bashrc

# echo "cd ${APPDIR}" | tee -a $HDIR/.bashrc && \
# mkdir -p $HDIR/go/{src,pkg,bin}
# chown -R vagrant $HDIR/go


# Step: Copying fixtures folder
# mkdir -p ~/go/src/github.com/chainHero/heroes-service/
# cp -r /opt/app/fixtures/ ~/go/src/github.com/chainHero/heroes-service/~