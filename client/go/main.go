package main

import (
	"fmt"

	"github.com/prism/prism/prism"
	"google.golang.org/protobuf/proto"
)

const (
	ADDR = "127.0.0.1"
	PORT = 6969
	KEY  = "secret-auth-key-123============="
)

func main() {
	p := prism.NewPrism(ADDR, PORT, KEY)
	if err := p.Start(); err != nil {
		fmt.Println("Error starting UDP client:", err)
		return
	}
	login := prism.Login{
		Service: "default_service",
		Token:   "default_token",
	}

	rawLogin, err := proto.Marshal(&login)
	if err != nil {
		panic(err)
	}

	err = p.Send(rawLogin, prism.DATA)
	if err != nil {
		fmt.Println("Failed to send login:", err)
	}

	data := prism.DataPacket{
		Type: 4,
		Payload: &prism.DataPacket_Update{
			Update: &prism.Update{
				Name:         "test-name",
				Value:        "10",
				Type:         "KILLS",
				PersistCache: true,
			},
		},
	}

	rawData, err := proto.Marshal(&data)
	if err != nil {
		panic(err)
	}

	err = p.Send(rawData, prism.DATA)
	if err != nil {
		fmt.Println("Failed to send data packet:", err)
	}

	select {}
}
