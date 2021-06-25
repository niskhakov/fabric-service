#!/bin/bash

# It has no dependencies on purpose 

# vars for running fabric bins
export PATH=${PWD}/.bin:$PATH
export FABRIC_CFG_PATH=${PWD}
export CORE_PEER_TLS_ENABLED=true
export PEER0_ORG1_CA=${PWD}/fixtures/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export PEER0_ORG2_CA=${PWD}/fixtures/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export PEER0_ORG3_CA=${PWD}/fixtures/crypto-config/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export ORDERER_CA=${PWD}/fixtures/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export ORDERER_ADMIN_TLS_SIGN_CERT=${PWD}/fixtures/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
export ORDERER_ADMIN_TLS_PRIVATE_KEY=${PWD}/fixtures/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key

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

function errorln() {
  println "${C_RED}${1}${C_RESET}"
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

function verifyResult() {
  if [ $1 -ne 0 ]; then
    fatalln "$2"
  fi
}

# parsePeerConnectionParameters $@
# Helper function that sets the peer connection parameters for a chaincode
# operation
parsePeerConnectionParameters() {
  PEER_CONN_PARMS=()
  PEERS=""
  while [ "$#" -gt 0 ]; do
    setGlobals $1
    PEER="peer0.org$1"
    ## Set peer addresses
    if [ -z "$PEERS" ]
    then
	PEERS="$PEER"
    else
	PEERS="$PEERS $PEER"
    fi
    PEER_CONN_PARMS=("${PEER_CONN_PARMS[@]}" --peerAddresses $CORE_PEER_ADDRESS)
    ## Set path to TLS certificate
    CA=PEER0_ORG$1_CA
    TLSINFO=(--tlsRootCertFiles "${!CA}")
    PEER_CONN_PARMS=("${PEER_CONN_PARMS[@]}" "${TLSINFO[@]}")
    # shift by one to get to the next organization
    shift
  done
}



#### Main Logic Functions and Vars

CHANNEL_NAME=mychannel
CC_NAME="basic" # chaincode name
CC_SRC_PATH="./chaincode/basic" # chaincode path
CC_SRC_LANGUAGE="go" # chaincode language
CC_VERSION="1.0" # chaincode version
CC_SEQUENCE="1" # chaincode definition sequence
CC_INIT_FCN="InitLedger" # chaincode init function
# CC_END_POLICY="--signature-policy OR('Org1MSP.peer','Org2MSP.peer')" # endorsement policy
CC_END_POLICY="--signature-policy OutOf(1,'Org1MSP.peer','Org2MSP.peer')"
CC_COL_CONFIG="" # collection configuration 

FABRIC_CFG_PATH=".bin"
CC_RUNTIME_LANGUAGE="golang"
infoln "Vendoring Go dependencies at$CC_SRC_PATH"
pushd $CC_SRC_PATH
GO111MODULE=on go mod vendor
popd
successln "Finished vendoring Go dependencies"

# Package Chaincode
packageChaincode() {
  set -x
  peer lifecycle chaincode package ${CC_NAME}.tar.gz --path ${CC_SRC_PATH} --lang ${CC_RUNTIME_LANGUAGE} --label ${CC_NAME}_${CC_VERSION} 
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Chaincode packaging has failed"
  successln "Chaincode is packaged"
}

installChaincode() {
  ORG=$1
  setGlobals $ORG
  set -x
  peer lifecycle chaincode install basic.tar.gz
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Chaincode installation on peer0.org${ORG} has failed"
  successln "Chaincode is installed on peer0.org${ORG}"
}

queryInstalled() {
  ORG=$1
  setGlobals $1
  set -x
  peer lifecycle chaincode queryinstalled >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  PACKAGE_ID=$(sed -n "/${CC_NAME}_${CC_VERSION}/{s/^Package ID: //; s/, Label:.*$//; p;}" log.txt)
  verifyResult $res "Query installed on peer0.org${ORG} has failed"
  successln "Query installed successful on peer0.org${ORG} on channel"
}

approveForMyOrg() {
  ORG=$1
  setGlobals $ORG
  set -x
  peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile "$ORDERER_CA" --channelID $CHANNEL_NAME --name ${CC_NAME} --version ${CC_VERSION} --package-id ${PACKAGE_ID} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} ${CC_END_POLICY} ${CC_COLL_CONFIG} >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Chaincode definition approved on peer0.org${ORG} on channel '$CHANNEL_NAME' failed"
  successln "Chaincode definition approved on peer0.org${ORG} on channel '$CHANNEL_NAME'"
}

# checkCommitReadiness VERSION PEER ORG
checkCommitReadiness() {
  ORG=$1
  setGlobals $ORG
  infoln "Checking the commit readiness of the chaincode definition on peer0.org${ORG} on channel '$CHANNEL_NAME'..."
  infoln "Attempting to check the commit readiness of the chaincode definition on peer0.org${ORG}"
  set -x
  peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL_NAME --name ${CC_NAME} --version ${CC_VERSION} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} ${CC_END_POLICY} ${CC_COLL_CONFIG} --output json >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
}

commitChaincodeDefinition() {
  parsePeerConnectionParameters $@
  res=$?
  verifyResult $res "Invoke transaction failed on channel '$CHANNEL_NAME' due to uneven number of peer and org parameters "

  # while 'peer chaincode' command can get the orderer endpoint from the
  # peer (if join was successful), let's supply it directly as we know
  # it using the "-o" option
  set -x
  peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile "$ORDERER_CA" --channelID $CHANNEL_NAME --name ${CC_NAME} "${PEER_CONN_PARMS[@]}" --version ${CC_VERSION} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} ${CC_END_POLICY} ${CC_COLL_CONFIG} ">&log.txt"
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Chaincode definition commit failed on peer0.org${ORG} on channel '$CHANNEL_NAME' failed"
  successln "Chaincode definition committed on channel '$CHANNEL_NAME'"
}

queryCommitted() {
  ORG=$1
  setGlobals $ORG
  EXPECTED_RESULT="Version: ${CC_VERSION}, Sequence: ${CC_SEQUENCE}, Endorsement Plugin: escc, Validation Plugin: vscc"
  infoln "Querying chaincode definition on peer0.org${ORG} on channel '$CHANNEL_NAME'..."
  
  infoln "Attempting to Query committed status on peer0.org${ORG}"
  println "Expecting: ${EXPECTED_RESULT}"
  set -x
  peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name ${CC_NAME} >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
}

chaincodeInvokeInit() {
  parsePeerConnectionParameters $@
  res=$?
  verifyResult $res "Invoke transaction failed on channel '$CHANNEL_NAME' due to uneven number of peer and org parameters "

  # while 'peer chaincode' command can get the orderer endpoint from the
  # peer (if join was successful), let's supply it directly as we know
  # it using the "-o" option
  set -x
  fcn_call='{"function":"'${CC_INIT_FCN}'","Args":[]}'
  infoln "invoke fcn call:${fcn_call}"
  peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile "$ORDERER_CA" -C $CHANNEL_NAME -n ${CC_NAME} "${PEER_CONN_PARMS[@]}" -c ${fcn_call} >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Invoke execution on $PEERS failed "
  successln "Invoke transaction successful on $PEERS on channel '$CHANNEL_NAME'"
}

SLEEP_MAIN=5
packageChaincode

## Install chaincode on peer0.org1 and peer0.org2
infoln "Installing chaincode on peer0.org1..."
installChaincode 1

infoln "Install chaincode on peer0.org2..."
sleep $SLEEP_MAIN
installChaincode 2

## query whether the chaincode is installed

infoln "Query Installed chaincode on peer0.org1..."
sleep $SLEEP_MAIN
queryInstalled 1

## approve the definition for org1
infoln "Approve For My Org1"
sleep $SLEEP_MAIN
approveForMyOrg 1

infoln "checkCommitReadiness 1"
sleep $SLEEP_MAIN
checkCommitReadiness 1

infoln "Approve For My Org2"
sleep $SLEEP_MAIN
approveForMyOrg 2

infoln "checkCommitReadiness 2"
sleep $SLEEP_MAIN
checkCommitReadiness 2

infoln "commitChaincodeDefinition 1 2"
sleep $SLEEP_MAIN
commitChaincodeDefinition 1 2

infoln "Query Commited 1 and 2"
sleep $SLEEP_MAIN
queryCommitted 1
sleep $SLEEP_MAIN
queryCommitted 2

infoln "chaincodeInvokeInit 1 2 -> InitLedger invokation"
sleep $SLEEP_MAIN
chaincodeInvokeInit 1 2

infoln "Quering the chaincode: Get All Assets"
sleep $SLEEP_MAIN
peer chaincode query -C mychannel -n basic -c '{"Args":["GetAllAssets"]}'