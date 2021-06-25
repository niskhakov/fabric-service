.PHONY: all dev clean build env-up env-down run

all: clean build env-up run

dev: build run

#### Build
build:
	@echo "Build ..."
	@cd chaincode && GO111MODULE=on go mod vendor
	@go build
	@echo "Build done"

#### Env
env-up:
	@echo "Start environment ..."
	@cd fixtures && docker-compose up --force-recreate -d
	@echo "Environment up"

env-down:
	@echo "Stop environment ..."
	@cd fixtures && docker-compose down
	@echo "Environment down"

#### Run

network:
	@echo "Deploying test network ..."
	@./c_createfixtures.sh
	@echo "Deploying done"

network-all: network
	@echo "Deploying chaincode ..."
	@./c_deployCC.sh
	@echo "Deploying done"

chaincode:
	@echo "Deploying chaincode ..."
	@./c_deployCC.sh
	@echo "Deploying done"

logs:
	@cd fixtures && docker-compose logs -f

#### Clean
clean: env-down
	@echo "Clean up ..."
	@cd fixtures && docker-compose down --volumes --remove-orphans
	@docker rm -f `docker ps -aq --filter label=service=hyperledger-fabric` 2>/dev/null || true
	@docker rm -f `docker ps -aq --filter name='dev-peer*'` 2>/dev/null || true
	@docker image rm -f `docker images -aq --filter reference='dev-peer*'` 2>/dev/null || true
	@rm -f basic.tar.gz
	@rm -f log.txt
	@echo "Clean up done"


# Install gotools before comiling fabric
fabric-gotools:
	@cd ${GOPATH}/src/github.com/hyperledger/fabric/ && $(MAKE) gotools

# Generate protos from local fabric-protos repo
fabric-compile-protos:
	@cd ./hyperledger/fabric-protos && ./ci/build.sh
	
# Move interested files to fabric vendor folder to make sure fabric code using our files
fabric-substitute-protos: fabric-compile-protos 
	@cp ./hyperledger/fabric-protos/build/fabric-protos-go/peer/proposal.pb.go ${GOPATH}/src/github.com/hyperledger/fabric/vendor/github.com/hyperledger/fabric-protos-go/peer/proposal.pb.go
	@cp ./hyperledger/fabric-protos/build/fabric-protos-go/peer/proposal.pb.go ./vendor/github.com/hyperledger/fabric-protos-go/peer/proposal.pb.go

# Compile fabric (takes too long with slow internet connection)
fabric-build:
	@cd ${GOPATH}/src/github.com/hyperledger/fabric/ && $(MAKE) clean docker-clean peer orderer peer-docker orderer-docker configtxgen configtxlator cryptogen tools-docker docker-thirdparty docker

# Copy build artefacts after compilation to local folder, they will be used during deploying in c_network.sh
fabric-use-build-bins:
	@cp ./hyperledger/fabric/build/bin/* ./.bin/

fix-docker:
	@sudo chmod 666 /var/run/docker.sock