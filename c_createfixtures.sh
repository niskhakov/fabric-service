#!/bin/bash

# It has no dependencies on purpose 

#### Start Common Script Settings
export CHANNEL_NAME="mychannel"
export BLOCKFILE=fixtures/artifacts/${CHANNEL_NAME}.block
export ANCHOR_PEER_SH="./c_anchorPeer.sh"
#### End Common Script Settings


export PATH=${PWD}/.bin:$PATH
export FABRIC_CFG_PATH=${PWD}
# vars for running fabric bins
export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/fixtures/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export PEER0_ORG1_CA=${PWD}/fixtures/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export PEER0_ORG2_CA=${PWD}/fixtures/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export PEER0_ORG3_CA=${PWD}/fixtures/crypto-config/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export PEER0_ORG4_CA=${PWD}/fixtures/crypto-config/peerOrganizations/org4.example.com/peers/peer0.org4.example.com/tls/ca.crt
export PEER0_ORG5_CA=${PWD}/fixtures/crypto-config/peerOrganizations/org5.example.com/peers/peer0.org5.example.com/tls/ca.crt
export ORDERER_ADMIN_TLS_SIGN_CERT=${PWD}/fixtures/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
export ORDERER_ADMIN_TLS_PRIVATE_KEY=${PWD}/fixtures/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key

#### Function to Operate Env Vars
setGlobals() {
  local USING_ORG=""
  if [ -z "$OVERRIDE_ORG" ]; then
    USING_ORG=$1
  else
    USING_ORG="${OVERRIDE_ORG}"
  fi
  infoln "Using organization ${USING_ORG}"

  local ORG_NUM=$1
  export CORE_PEER_LOCALMSPID="Org${ORG_NUM}MSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/fixtures/crypto-config/peerOrganizations/org${ORG_NUM}.example.com/peers/peer0.org${ORG_NUM}.example.com/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=${PWD}/fixtures/crypto-config/peerOrganizations/org${ORG_NUM}.example.com/users/Admin@org${ORG_NUM}.example.com/msp
  export CORE_PEER_ADDRESS=localhost:$((5 + ORG_NUM * 2))051
  
  # if [ $USING_ORG -eq 1 ]; then
  #   export CORE_PEER_LOCALMSPID="Org1MSP"
  #   export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG1_CA
  #   export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
  #   export CORE_PEER_ADDRESS=localhost:7051
  # elif [ $USING_ORG -eq 2 ]; then
  #   export CORE_PEER_LOCALMSPID="Org2MSP"
  #   export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG2_CA
  #   export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
  #   export CORE_PEER_ADDRESS=localhost:9051

  # elif [ $USING_ORG -eq 3 ]; then
  #   export CORE_PEER_LOCALMSPID="Org3MSP"
  #   export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG3_CA
  #   export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
  #   export CORE_PEER_ADDRESS=localhost:11051
  # else
  #   errorln "ORG Unknown"
  # fi

  if [ "$VERBOSE" == "true" ]; then
    env | grep CORE
  fi
}


#### Utility Functions

C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_BLUE='\033[0;34m'
C_YELLOW='\033[1;33m'

# println echos string
function println() {
  echo -e "$1"
}
# infoln echos in blue color
function infoln() {
  println "${C_BLUE}${1}${C_RESET}"
}
# fatalln echos in red color and exits with fail status
function fatalln() {
  errorln "$1"
  exit 1
}
# successln echos in green color
function successln() {
  println "${C_GREEN}${1}${C_RESET}"
}

function errorln() {
  println "${C_RED}${1}${C_RESET}"
}

function verifyResult() {
  if [ $1 -ne 0 ]; then
    fatalln "$2"
  fi
}



#### Main Logic Functions

function createOrgs() {
  if [ -d "fixtures/crypto-config" ]; then
    rm -Rf fixtures/crypto-config
  fi

  which cryptogen
  if [ "$?" -ne 0 ]; then
    fatalln "cryptogen tool not found. exiting"
  fi

  infoln "Generating certificates using cryptogen tool for all nodes"
  set -x 
  cryptogen generate --config=./crypto-config.yaml --output="fixtures/crypto-config"
  res=$?
  { set +x; } 2>/dev/null
  if [ $res -ne 0 ]; then
    fatalln "Failed to generate certificates..."
  fi

  ## CCP Files ?
}

function createChannelGenesisBlock() {
  which configtxgen
	if [ "$?" -ne 0 ]; then
		fatalln "configtxgen tool not found."
	fi
	set -x
	configtxgen -profile OrgsApplicationGenesis -outputBlock $BLOCKFILE -channelID $CHANNEL_NAME
	res=$?
	{ set +x; } 2>/dev/null
}

function createChannel() {
  setGlobals 1
  set -x
  osnadmin channel join --channelID $CHANNEL_NAME --config-block ${BLOCKFILE} -o localhost:7053 --ca-file "$ORDERER_CA" --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY" # >&log.txt
	res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Channel creation failed"
}

function networkUp() {
  make env-up
}

function joinChannel() {
  # Used global vars: BLOCKFILE
  # Args: ORG_NUM
  local SLEEP_DELAY=5
  FABRIC_CFG_PATH=$PWD/.bin # Use config files by default for peer command, i.e. (configtx.yaml, core.yaml, orderer.yaml)

  ORG=$1
  setGlobals ${ORG}
  sleep ${SLEEP_DELAY}
  set -x
  peer channel join -b $BLOCKFILE >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "peer0.org${ORG} has failed to join channel '$CHANNEL_NAME'"

}

function setAnchorPeer() {
  # Used global vars: CHANNEL_NAME
  # Args: ORG_NUM 
  ORG=$1
  set +x
  docker exec cli /opt/gopath/src/github.com/hyperledger/fabric/peer/scripts/c_anchorPeers.sh $ORG $CHANNEL_NAME
  { set +x; } 2>/dev/null
}

createOrgs
createChannelGenesisBlock
networkUp
createChannel
joinChannel 1
joinChannel 2
joinChannel 3
joinChannel 4
joinChannel 5
setAnchorPeer 1
setAnchorPeer 2
setAnchorPeer 3
setAnchorPeer 4
setAnchorPeer 5