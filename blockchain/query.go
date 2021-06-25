package blockchain

import (
	"fmt"
	"strings"

	"github.com/hyperledger/fabric-sdk-go/pkg/client/channel"
	"github.com/hyperledger/fabric-sdk-go/pkg/client/resmgmt"
	"github.com/hyperledger/fabric-sdk-go/pkg/common/providers/fab"
)

type EndorsementInfo struct {
	NOutOf int
	PeersMSPIds []string
}

// QueryHello query the chaincode to get the state of hello
func (setup *FabricSetup) QueryRead() (string, error) {

	// Prepare arguments
	var args []string
	args = append(args, "GetAllAssets")

	// response, err := setup.client.Query(channel.Request{ChaincodeID: setup.ChainCodeID, Fcn: args[0], Args: [][]byte{[]byte(args[1]), []byte(args[2])}})
	response, err := setup.client.Query(channel.Request{ChaincodeID: setup.ChainCodeID, Fcn: args[0]})
	if err != nil {
		return "", fmt.Errorf("failed to query: %v", err)
	}

	return string(response.Payload), nil
}

func (setup *FabricSetup) QueryLedger() (*fab.BlockchainInfoResponse, error) {
	response, err := setup.ledger.QueryInfo()
	if err != nil {
		fmt.Println(err)
		return nil, err
	}
	
	return response, nil
}

func (setup *FabricSetup) QueryLedgerConfig() (fab.ChannelCfg, error) {
	response, err := setup.ledger.QueryConfig()
	if err != nil {
		fmt.Println(err)
		return nil, err
	}
	
	return response, nil
}

func (setup *FabricSetup) QueryCC() (*EndorsementInfo, error) {

	req := resmgmt.LifecycleQueryCommittedCCRequest{
		Name: setup.ChainCodeID,
	}
	response, err := setup.admin.LifecycleQueryCommittedCC(setup.ChannelID, req)
	if err != nil {
		fmt.Println(err)
		return nil, err
	}

	var info EndorsementInfo

	for _, v := range response {
		info.NOutOf = int(v.SignaturePolicy.Rule.GetNOutOf().N)
		// rules := v.SignaturePolicy.Rule.GetNOutOf().Rules
		// for k, d := range rules {
		// 	fmt.Println(k, d)
		// }
		info.PeersMSPIds = make([]string, 0)
		ids := v.SignaturePolicy.Identities

		for _, z := range ids {
			info.PeersMSPIds = append(info.PeersMSPIds, strings.TrimSpace(string(z.GetPrincipal())))
		}
	}
	
	return &info, nil
}