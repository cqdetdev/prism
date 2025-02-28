package main

import (
	"encoding/binary"
	"errors"
	"fmt"
	"hash/crc32"
	"math/rand"
	"net"
	"sync"
	"time"

	"google.golang.org/protobuf/proto"
)

type Prism struct {
	host        string
	port        int
	conn        net.Conn
	pendingAcks sync.Map
}

func NewPrism(host string, port int) *Prism {
	return &Prism{
		host: host,
		port: port,
	}
}

func (o *Prism) Start() error {
	conn, err := net.Dial("udp", "127.0.0.1:6969")
	if err != nil {
		return err
	}
	o.conn = conn

	go o.listen()
	return nil
}

func (o *Prism) listen() {
	buffer := make([]byte, 1024)
	for {
		n, err := o.conn.Read(buffer)
		if err != nil {
			fmt.Println("Error reading from UDP:", err)
			continue
		}

		if n < 5 {
			fmt.Println("Received too short packet")
			continue
		}

		buffer = buffer[:n]

		typeID := buffer[0]
		seqNum := binary.BigEndian.Uint32(buffer[1:5])

		switch typeID {
		case 1:
			o.handleDataPacket(buffer[5:n], seqNum)
		case 2:
			o.handleAckPacket(seqNum)
		default:
			fmt.Println("Unknown packet type received")
		}
	}
}

func (o *Prism) handleDataPacket(data []byte, seqNum uint32) {
	fmt.Printf("Received Data Packet (seqNum: %d, data: %x)\n", seqNum, data)
	ack := make([]byte, 5)
	ack[0] = 2
	binary.BigEndian.PutUint32(ack[1:], seqNum)
	o.conn.Write(ack)
}

func (o *Prism) handleAckPacket(seqNum uint32) {
	if ch, ok := o.pendingAcks.Load(seqNum); ok {
		close(ch.(chan struct{}))
		o.pendingAcks.Delete(seqNum)
		fmt.Printf("ACK confirmed, removed seqNum %d from pending list\n", seqNum)
	} else {
		fmt.Printf("Received ACK for unknown seqNum: %d\n", seqNum)
	}
}

func (o *Prism) Send(data []byte, requestType int) error {
	seqNum := rand.Uint32()
	header := make([]byte, 9)
	header[0] = byte(requestType)
	binary.BigEndian.PutUint32(header[1:], seqNum)

	combined := append(header, data...)
	checksum := crc32.ChecksumIEEE(combined)
	binary.BigEndian.PutUint32(header[5:], checksum)

	packet := append(header, data...)

	ackChan := make(chan struct{})
	o.pendingAcks.Store(seqNum, ackChan)

	if _, err := o.conn.Write(packet); err != nil {
		o.pendingAcks.Delete(seqNum)
		return err
	}

	select {
	case <-ackChan:
		return nil
	case <-time.After(5 * time.Second):
		o.pendingAcks.Delete(seqNum)
		return errors.New(fmt.Sprintf("ACK not received for seqNum: %d", seqNum))
	}
}

const (
	ADDR = "127.0.0.1"
	PORT = 6969
)

func main() {
	Prism := NewPrism(ADDR, PORT)
	if err := Prism.Start(); err != nil {
		fmt.Println("Error starting UDP client:", err)
		return
	}
	login := Login{
		Service: "default_service",
		Token:   "default_token",
	}

	rawLogin, err := proto.Marshal(&login)
	if err != nil {
		panic(err)
	}

	_, err = Prism.conn.Write(rawLogin)
	if err != nil {
		fmt.Println("Failed to send login:", err)
	}

	data := DataPacket{
		Type: 4,
		Payload: &DataPacket_Update{
			Update: &Update{
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

	_, err = Prism.conn.Write(rawData)
	if err != nil {
		fmt.Println("Failed to send data packet:", err)
	}

	select {}
}
