package main

import (
	"bytes"
	"encoding/hex"
	"fmt"

	"github.com/google/keytransparency/core/crypto/vrf/p256"
)

func h2i(h string) [32]byte {
	b, err := hex.DecodeString(h)
	if err != nil {
		panic("Invalid hex")
	}
	var i [32]byte
	copy(i[:], b)
	return i
}


const (
	// openssl ecparam -name prime256v1 -genkey -out p256-key.pem
	privKey = `-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIGbhE2+z8d5lHzb0gmkS78d86gm5gHUtXCpXveFbK3pcoAoGCCqGSM49
AwEHoUQDQgAEUxX42oxJ5voiNfbjoz8UgsGqh1bD1NXK9m8VivPmQSoYUdVFgNav
csFaQhohkiCEthY51Ga6Xa+ggn+eTZtf9Q==
-----END EC PRIVATE KEY-----`
	// openssl ec -in p256-key.pem -pubout -out p256-pubkey.pem
	pubKey = `-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEUxX42oxJ5voiNfbjoz8UgsGqh1bD
1NXK9m8VivPmQSoYUdVFgNavcsFaQhohkiCEthY51Ga6Xa+ggn+eTZtf9Q==
-----END PUBLIC KEY-----`
)


func main() {
	k, err := p256.NewVRFSignerFromPEM([]byte(privKey))
	if err != nil {
		fmt.Printf("NewVRFSigner Failed: %v\n", err)
	}
	fmt.Println(k.Public())
	
	
	pk, err := p256.NewVRFVerifierFromPEM([]byte(pubKey))
	if err != nil {
		fmt.Printf("NewVRFSigner failure: %v\n", err)
	}

	fmt.Println(pk)

	// b, _ := pem.Decode([]byte(pubKey))
	// key, err := x509.ParsePKIXPublicKey(b.Bytes)
	// if err != nil {
	// 	fmt.Printf("Error while constructing public key: %v\n", err)
	// }
	// newpk, ok := key.(*ecdsa.PublicKey)
	// if !ok {
	// 	fmt.Printf("Error while conversion to public key: %v\n", err)
	// }

	// fmt.Println(newpk)

	var bb bytes.Buffer
	bb.WriteString("basic")
	bb.WriteString(":")
	bb.WriteString("CreateAsset")
	bb.WriteString(":")
	bb.WriteString("13")
	// 
	m := bb.Bytes()
	index, proof := k.Evaluate(m)
	fmt.Printf("VRF Output: %v \n", hex.EncodeToString(index[:]))
	fmt.Printf("VRF Proof: %v\n", hex.EncodeToString(proof))


	index2, err := pk.ProofToHash(m, proof)
	if err != nil {
		fmt.Printf("Error ProofOfHash: %v\n", err)
	}

	fmt.Printf("VRF Verification output: %v\n", hex.EncodeToString(index2[:]))

	if got, want := index2, index; got != want {
		fmt.Printf("ProofToHash(%s): %x, want %x \n", bb.String(), got, want)
	} else {
		fmt.Printf("ProofToHash(%s): got right hash \n", bb.String())
	}
}
