package blockchain

import (
	"crypto/x509"
	"encoding/base64"
	"fmt"

	"fabric-service/vrf"
	"fabric-service/vrf/p256"

	"github.com/hyperledger/fabric-sdk-go/pkg/client/channel"
	"github.com/hyperledger/fabric-sdk-go/pkg/client/ledger"
	mspclient "github.com/hyperledger/fabric-sdk-go/pkg/client/msp"
	"github.com/hyperledger/fabric-sdk-go/pkg/client/resmgmt"
	"github.com/hyperledger/fabric-sdk-go/pkg/core/config"
	"github.com/hyperledger/fabric-sdk-go/pkg/fabsdk"
	"github.com/pkg/errors"
)

// FabricSetup implementation
type FabricSetup struct {
	ConfigFile      string
	OrgID           string
	OrdererID       string
	ChannelID       string
	ChainCodeID     string
	initialized     bool
	ChannelConfig   string
	OrgAdmin        string
	OrgName         string
	UserName        string
	vrfSigner				*vrf.PrivateKey
	vrfVerifier     *vrf.PublicKey
	client          *channel.Client
	admin           *resmgmt.Client
	ledger 					*ledger.Client
	sdk             *fabsdk.FabricSDK
	// event           *event.Client
}

// Initialize reads the configuration file and sets up the client, chain and event hub
func (setup *FabricSetup) Initialize() error {

	// Add parameters for the initialization
	if setup.initialized {
		return errors.New("sdk already initialized")
	}

	// Initialize the SDK with the configuration file
	sdk, err := fabsdk.New(config.FromFile(setup.ConfigFile))
	if err != nil {
		return errors.WithMessage(err, "failed to create SDK")
	}
	setup.sdk = sdk
	fmt.Println("SDK created")

	// The resource management client is responsible for managing channels (create/update channel)
	resourceManagerClientContext := setup.sdk.Context(fabsdk.WithUser(setup.OrgAdmin), fabsdk.WithOrg(setup.OrgName))
	if err != nil {
		return errors.WithMessage(err, "failed to load Admin identity")
	}
	resMgmtClient, err := resmgmt.New(resourceManagerClientContext)
	if err != nil {
		return errors.WithMessage(err, "failed to create channel management client from Admin identity")
	}
	setup.admin = resMgmtClient
	fmt.Println("Resource management client created")

	// The MSP client allow us to retrieve user information from their identity, like its signing identity which we will need to save the channel
	mspClient, err := mspclient.New(sdk.Context(), mspclient.WithOrg(setup.OrgName))
	if err != nil {
		return errors.WithMessage(err, "failed to create MSP client")
	}
	// adminIdentity, err := mspClient.GetSigningIdentity(setup.OrgAdmin)
	// if err != nil {
	// 	return errors.WithMessage(err, "failed to get admin signing identity")
	// }

	// fmt.Println(adminIdentity.PrivateKey().Bytes())



	// req := resmgmt.SaveChannelRequest{ChannelID: setup.ChannelID, ChannelConfigPath: setup.ChannelConfig, SigningIdentities: []msp.SigningIdentity{adminIdentity}}
	// txID, err := setup.admin.SaveChannel(req, resmgmt.WithOrdererEndpoint(setup.OrdererID))
	// if err != nil || txID.TransactionID == "" {
	// 	return errors.WithMessage(err, "failed to save channel")
	// }
	// fmt.Println("Channel created")

	// Make admin user join the previously created channel
	// if err = setup.admin.JoinChannel(setup.ChannelID, resmgmt.WithRetry(retry.DefaultResMgmtOpts), resmgmt.WithOrdererEndpoint(setup.OrdererID)); err != nil {
	// 	return errors.WithMessage(err, "failed to make admin join channel")
	// }
	// fmt.Println("Channel joined")

	// Channel client is used to query and execute transactions
	clientContext := setup.sdk.ChannelContext(setup.ChannelID, fabsdk.WithUser(setup.UserName))
	setup.client, err = channel.New(clientContext)
	if err != nil {
		return errors.WithMessage(err, "failed to create new channel client")
	}
	fmt.Println("Channel client created")

	clientIdentity, err := mspClient.GetSigningIdentity(setup.UserName)
	if err != nil {
		return errors.WithMessage(err, "failed to get admin signing identity")
	}
	cpk, err := clientIdentity.PrivateKey().PublicKey()
	if err != nil {
		fmt.Printf("Cannot get public key of client: %v \n", err)
	}

	cprivkey := clientIdentity.PrivateKey()
	privkb, err := cprivkey.Bytes()
	if err != nil {
		fmt.Println("Cannot encode private key to bytes")
	}

	// privPem, _ := pem.Decode(privkb)
	// if privPem == nil {
	// 	fmt.Println("Cannot decode private key from bytes")
	// }

	// privateKey, err := x509.ParseECPrivateKey(privPem.Bytes)
	// if err != nil {
	// 	fmt.Println("Cannot decode x509 Pem Private Key", err)
	// }

	pkb, err := cpk.Bytes()
	if err != nil {
		fmt.Println("Cannot encode csp key to pkixpk")
	}

	vrfEncoder, err := p256.NewVRFSignerFromPEM(privkb)
	if err != nil {
		fmt.Println("Cannot create vrf encoder", err)
	}
	
	vrfVerifier, err := p256.NewVRFVerifierFromRawKey(pkb)
	if err != nil {
		fmt.Println("Cannot create vrf verifier")
	}

	setup.vrfSigner = &vrfEncoder
	fmt.Println("VRF Public Key", vrfEncoder.Public())
	
	setup.vrfVerifier = &vrfVerifier


	pubkey, err := x509.ParsePKIXPublicKey(pkb)
	if err != nil {
		fmt.Println("Canntot parse decoded pubkey")
	}

	fmt.Printf("Client pubkey: %v \n", pubkey)

	pkbytes, err := x509.MarshalPKIXPublicKey(pubkey)
	if err != nil {
		fmt.Println("Cannot marshal pkixpk")
	}


	pkencoded := base64.RawStdEncoding.EncodeToString(pkbytes)

	fmt.Printf("Client pubkey encoded base64: %v \n", pkencoded)


	ledgerContext := setup.sdk.ChannelContext(setup.ChannelID, fabsdk.WithUser(setup.UserName))
	ledgerClient, err := ledger.New(ledgerContext)
	if err != nil {
		return errors.WithMessage(err, "failed to create ledger client")
	}
	setup.ledger = ledgerClient

	fmt.Println("Initialization Successful")
	setup.initialized = true
	return nil
}

func (setup *FabricSetup) GetVRFSigner() *vrf.PrivateKey {
	return setup.vrfSigner
}

func (setup *FabricSetup) GetVRFVerifier() *vrf.PublicKey {
	return setup.vrfVerifier
}

// func (setup *FabricSetup) InstallAndInstantiateCC() error {

// 	// Create the chaincode package that will be sent to the peers
// 	ccPkg, err := packager.NewCCPackage(setup.ChaincodePath, setup.ChaincodeGoPath)
// 	if err != nil {
// 		return errors.WithMessage(err, "failed to create chaincode package")
// 	}
// 	fmt.Println("ccPkg created")

// 	// Install example cc to org peers
// 	installCCReq := resmgmt.InstallCCRequest{Name: setup.ChainCodeID, Path: setup.ChaincodePath, Version: "0", Package: ccPkg}
// 	_, err = setup.admin.InstallCC(installCCReq, resmgmt.WithRetry(retry.DefaultResMgmtOpts))
// 	if err != nil {
// 		return errors.WithMessage(err, "failed to install chaincode")
// 	}
// 	fmt.Println("Chaincode installed")

// 	// Set up chaincode policy
// 	ccPolicy := cauthdsl.SignedByAnyMember([]string{"org1.fabric-service.net"})

// 	resp, err := setup.admin.InstantiateCC(setup.ChannelID, resmgmt.InstantiateCCRequest{Name: setup.ChainCodeID, Path: setup.ChaincodeGoPath, Version: "0", Args: [][]byte{[]byte("init")}, Policy: ccPolicy})
// 	if err != nil || resp.TransactionID == "" {
// 		return errors.WithMessage(err, "failed to instantiate the chaincode")
// 	}
// 	fmt.Println("Chaincode instantiated")



// 	// Creation of the client which will enables access to our channel events
// 	setup.event, err = event.New(clientContext)
// 	if err != nil {
// 		return errors.WithMessage(err, "failed to create new event client")
// 	}
// 	fmt.Println("Event client created")

// 	fmt.Println("Chaincode Installation & Instantiation Successful")
// 	return nil
// }

func (setup *FabricSetup) CloseSDK() {
	setup.sdk.Close()
}
