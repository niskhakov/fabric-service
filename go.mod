module fabric-service

go 1.13

require (
	github.com/hyperledger/fabric-sdk-go v1.0.0
	github.com/pkg/errors v0.9.1
	google.golang.org/protobuf v1.26.0 // indirect
)

replace github.com/hyperledger/fabric-sdk-go => ./hyperledger/fabric-sdk-go

replace github.com/hyperledger/fabric-protos-go => ./hyperledger/fabric-protos-go
