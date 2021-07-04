package blockchain

import (
	"fmt"

	"github.com/hyperledger/fabric-protos-go/peer"
	"github.com/hyperledger/fabric-sdk-go/pkg/client/channel"
)

// InvokeHello
func (setup *FabricSetup) InvokeCC(args []string, targetPeers []string, randomization *peer.Randomization) (string, error) {

	

	// eventID := "eventInvoke"

	// Add data that will be visible in the proposal, like a description of the invoke request
	transientDataMap := make(map[string][]byte)
	// transientDataMap["result"] = []byte("Transient data in hello invoke")

	// reg, notifier, err := setup.event.RegisterChaincodeEvent(setup.ChainCodeID, eventID)
	// if err != nil {
	// 	return "", err
	// }
	// defer setup.event.Unregister(reg)

	// Create a request (proposal) and send it
	fmt.Printf("Tx: sending tx proposal to: %s\n", targetPeers)
	response, err := setup.client.Execute(channel.Request{
		ChaincodeID: setup.ChainCodeID, 
		Fcn: args[0], 
		Args: [][]byte{[]byte(args[1]), []byte(args[2]), []byte(args[3]), []byte(args[4]), []byte(args[5])}, 
		TransientMap: transientDataMap,
		Randomization: randomization,
		}, 
		channel.WithTargetEndpoints(targetPeers...))

	if err != nil {
		return "", fmt.Errorf("failed to move funds: %v", err)
	}

	// fmt.Println(response.Payload, response.Proposal.TxnID)

	// // args = args[:0]
	// args = append(args, "ReadAsset")
	// args = append(args, "asset13")
	// response, err := setup.client.Query(channel.Request{ChaincodeID: setup.ChainCodeID, Fcn: args[0], Args: [][]byte{[]byte(args[1])}})
	// if err != nil {
	// 	return "", fmt.Errorf("failed to query: %v", err)
	// }

	// // fmt.Println(response.Payload)
	// fmt.Printf("Response from the query hello: %s\n", response.Payload)

	// // Wait for the result of the submission
	// select {
	// case ccEvent := <-notifier:
	// 	fmt.Printf("Received CC event: %v\n", ccEvent)
	// case <-time.After(time.Second * 20):
	// 	return "", fmt.Errorf("did NOT receive CC event for eventId(%s)", eventID)
	// }

	return string(response.TransactionID), nil
}
