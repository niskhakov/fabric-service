package main

import (
	"encoding/hex"
	"fabric-service/blockchain"
	"fmt"
	"io/ioutil"
	"os"
	"regexp"
	"sort"
)

func main() {
	// Definition of the Fabric SDK properties
	fSetup := blockchain.FabricSetup{
		// Network parameters
		OrdererID: "orderer.example.com",

		// Channel parameters
		ChannelID:     "mychannel",
		ChannelConfig: os.Getenv("GOPATH") + "/src/github.com/chainHero/heroes-service/fixtures/artifacts/mychannel.block",

		// Chaincode parameters
		ChainCodeID:     "basic",
		// ChaincodeGoPath: os.Getenv("GOPATH"),
		// ChaincodePath:   "github.com/chainHero/heroes-service/chaincode/",
		OrgAdmin:        "Admin",
		OrgName:         "Org1",
		ConfigFile:      "config.yaml",

		// User parameters
		UserName: "User1",
	}

	// Initialization of the Fabric SDK from the previously set properties
	err := fSetup.Initialize()
	if err != nil {
		fmt.Printf("Unable to initialize the Fabric SDK: %v\n", err)
		return
	}
	// Close SDK
	defer fSetup.CloseSDK()

	// // Install and instantiate the chaincode
	// err = fSetup.InstallAndInstantiateCC()
	// if err != nil {
	// 	fmt.Printf("Unable to install and instantiate the chaincode: %v\n", err)
	// 	return
	// }

	// // Query the chaincode
	// response, err := fSetup.QueryRead()
	// if err != nil {
	// 	fmt.Printf("Unable to query hello on the chaincode: %v\n", err)
	// } else {
	// 	fmt.Printf("Response from the query hello: %s\n", response)
	// }

	blockchainInfo, err := fSetup.QueryLedger()
	if err != nil && blockchainInfo.Status != 200 {
		fmt.Printf("Unable to query ledger or return status is not 200")
	}
	fmt.Printf("Last block hash: %s\n", hex.EncodeToString(blockchainInfo.BCI.CurrentBlockHash))
	fmt.Printf("Ledger height: %d\n", blockchainInfo.BCI.Height)

	channelConfig, err := fSetup.QueryLedgerConfig()
	if err != nil {
		fmt.Printf("Unable to query ledger config")
	}
	apeers := channelConfig.AnchorPeers()
	peerMap := make(map[string]string)
	fmt.Println("Anchor peers:")
	for i, v := range apeers {
		fmt.Println("\t", i, v.Host, v.Org, v.Port)
		peerMap[v.Org] = v.Host
	}
	
	endorsementInfo, err := fSetup.QueryCC()
	if err != nil {
		fmt.Printf("Error while querying chaincode endorsement policy details: %v\n", err)
	}

	fmt.Printf("Endorsement info: \n\tOutOf: %d\n", endorsementInfo.NOutOf)

	for _, v := range endorsementInfo.PeersMSPIds {
		fmt.Printf("\tPeer: %s\n", v)
	}

	sort.Strings(endorsementInfo.PeersMSPIds)

	fmt.Printf("\n\n#### Calculating peers according to input data\n")
	os := blockchain.NewOrgSelector(blockchainInfo.BCI.CurrentBlockHash, endorsementInfo.NOutOf, len(endorsementInfo.PeersMSPIds), ioutil.Discard)
	ids := os.SelectOrgs()
	fmt.Println("According to randomized endorsement, tx must be sent to these ids: ", ids)
	chosenPeers := *os.MapToPeerSlice(endorsementInfo.PeersMSPIds)
	for _, v := range chosenPeers {
		fmt.Printf("\tPeer: %s\n", v)
	}

	chosenHosts := make([]string, 0)

	fmt.Printf("\n\n#### Sending transaction")
	for _, v := range chosenPeers {
		reg, err := regexp.Compile("[^a-zA-Z0-9]+")
    if err != nil {
        fmt.Println(err)
    }
    processedString := reg.ReplaceAllString(v, "")
		host, ok := peerMap[processedString]
		fmt.Println(host)
		if !ok {
			fmt.Printf("In required policy and in the channel there is no anchor peer: %s\n", v)
			break;
		}
		chosenHosts = append(chosenHosts, host)
	}


	// Invoke the chaincode
	txId, err := fSetup.InvokeCC(chosenHosts)
	if err != nil {
		fmt.Printf("Unable to invoke hello on the chaincode: %v\n", err)
	} else {
		fmt.Printf("Successfully invoke hello, transaction ID: %s\n", txId)
	}

	// // Query again the chaincode
	// response, err = fSetup.QueryHello()
	// if err != nil {
	// 	fmt.Printf("Unable to query hello on the chaincode: %v\n", err)
	// } else {
	// 	fmt.Printf("Response from the query hello: %s\n", response)
	// }
}
