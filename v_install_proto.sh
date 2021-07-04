PROTOC_VER=1.3.2
PROTOTOOL_VER=1.9.0
git clone -q -c advice.detachedHead=false -b v${PROTOC_VER} --depth 1 https://github.com/golang/protobuf
cd ./protobuf
sudo GOBIN=/usr/local/bin go install ./protoc-gen-go

PROTOTOOL_VER=1.8.0
sudo curl -sL -o /usr/local/bin/prototool https://github.com/uber/prototool/releases/download/v${PROTOTOOL_VER}/prototool-Linux-x86_64
sudo chmod +x /usr/local/bin/prototool
