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

const IV_LENGTH = 12
const TAG_LENGTH = 16

const (
	DATA = iota + 1
	ACK
	NACK
)

type Prism struct {
	host        string
	port        int
	conn        net.Conn
	pendingAcks sync.Map

	sec *security
}

func NewPrism(host string, port int, key string) *Prism {
	return &Prism{
		host: host,
		port: port,
		sec:  newSecurity(key),
	}
}

func (p *Prism) Start() error {
	conn, err := net.Dial("udp", "127.0.0.1:6969")
	if err != nil {
		return err
	}
	p.conn = conn

	go p.listen()
	return nil
}

func (p *Prism) listen() {
	buffer := make([]byte, 1024)
	for {
		n, err := p.conn.Read(buffer)
		if err != nil {
			fmt.Println("Error reading from UDP:", err)
			continue
		}

		if n < IV_LENGTH+TAG_LENGTH+9 {
			if buffer[0] == ACK {
				seq := binary.BigEndian.Uint32(buffer[1:5])
				p.handleAckPacket(seq)
			}
			continue
		}

		iv := buffer[:IV_LENGTH]
		ciphertext := buffer[IV_LENGTH : n-TAG_LENGTH]
		tag := buffer[n-TAG_LENGTH : n]

		if len(iv) != IV_LENGTH || len(tag) != TAG_LENGTH {
			fmt.Println("Invalid IV or tag length")
			continue
		}

		dec, err := p.sec.decrypt(iv, ciphertext, tag)
		if err != nil {
			fmt.Println("Failed to decrypt data packet", err)
			continue
		}

		typeID := dec[0]
		seq := binary.BigEndian.Uint32(dec[1:5])

		switch typeID {
		case 1:
			p.handleDataPacket(dec, seq)
		default:
			fmt.Println("Unknown packet type received")
		}
	}
}

func (p *Prism) handleDataPacket(data []byte, seq uint32) {
	seq = binary.BigEndian.Uint32(data[1:5])
	checksum := binary.BigEndian.Uint32(data[5:9])

	var pk DataPacket
	if err := proto.Unmarshal(data[9:], &pk); err != nil {
		fmt.Println("Failed to unmarshal data packet:", err)
		return
	}

	if crc32.ChecksumIEEE(data[9:]) != checksum {
		fmt.Println("Checksum mismatch, dropping packet")
		return
	}

	switch pk.Type {
	case 3:
		fmt.Println("Received AuthResponse for seq:", seq)
		ar := pk.GetAuthResponse()
		fmt.Println("AuthResponse:", ar)
	default:
		fmt.Println("Unknown packet type received")
	}

	ack := make([]byte, 5)
	ack[0] = 2
	binary.BigEndian.PutUint32(ack[1:], seq)
	p.conn.Write(ack)
}

func (p *Prism) handleAckPacket(seq uint32) {
	if ch, ok := p.pendingAcks.Load(seq); ok {
		close(ch.(chan struct{}))
		p.pendingAcks.Delete(seq)
		fmt.Printf("ACK confirmed, removed seq %d from pending list\n", seq)
	} else {
		fmt.Printf("Received ACK for unknown seq: %d\n", seq)
	}
}

func (p *Prism) Send(data []byte, requestType int) error {
	iv, ciphertext, tag := p.sec.encrypt(data)
	seq := rand.Uint32()
	header := make([]byte, 9)
	header[0] = byte(requestType)
	binary.BigEndian.PutUint32(header[1:], seq)

	combined := append(header, data...)
	checksum := crc32.ChecksumIEEE(combined)
	binary.BigEndian.PutUint32(header[5:], checksum)

	packet := append(header, iv...)
	packet = append(packet, ciphertext...)
	packet = append(packet, tag...)

	ackChan := make(chan struct{})
	p.pendingAcks.Store(seq, ackChan)

	if _, err := p.conn.Write(packet); err != nil {
		p.pendingAcks.Delete(seq)
		return err
	}

	select {
	case <-ackChan:
		return nil
	case <-time.After(5 * time.Second):
		p.pendingAcks.Delete(seq)
		return errors.New(fmt.Sprintf("ACK not received for seq: %d", seq))
	}
}

const (
	ADDR = "127.0.0.1"
	PORT = 6969
	KEY  = "secret-auth-key-123============="
)

func main() {
	prism := NewPrism(ADDR, PORT, KEY)
	if err := prism.Start(); err != nil {
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

	err = prism.Send(rawLogin, DATA)
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

	err = prism.Send(rawData, DATA)
	if err != nil {
		fmt.Println("Failed to send data packet:", err)
	}

	select {}
}
