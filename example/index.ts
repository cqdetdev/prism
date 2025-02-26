import type { Socket, udp } from "bun";
import { Field, Message, OneOf } from "protobufjs";
import { buf } from "crc-32";

class LoginRequest extends Message<LoginRequest> {
  @Field.d(1, "string", "required", "default_service")
  public service!: number;
  @Field.d(2, "string", "required", "default_service")
  public token!: string;
}

enum UpdateType {
  KILLS = "kills",
  DEATHS = "deaths",
}

enum AckType {
  DATA = 1,
  ACK = 2,
}

class UpdateRequest extends Message<UpdateRequest> {
  @Field.d(1, "string", "required")
  public name!: string;
  @Field.d(2, "string", "required")
  public value!: string | number;
  @Field.d(3, "string", "required")
  public type!: UpdateType;
  @Field.d(4, "bool", "required")
  public persistRedis!: boolean;
}

class DataPacket extends Message<DataPacket> {
  @Field.d(1, "int32", "required")
  public type!: number;
  
  @Field.d(2, LoginRequest)
  login?: LoginRequest;

  @Field.d(4, UpdateRequest)
  update?: UpdateRequest;

  @OneOf.d("login", "update")
  public payload!: LoginRequest | UpdateRequest;
}

const pendingAcks = new Map<number, [() => void, () => void]>();

const socket = await Bun.udpSocket({
  connect: {
    port: 6969,
    hostname: '127.0.0.1',
  },
  socket: {
    data(s, data) {
      const raw = Buffer.from(data);
      const type = raw[0];

      switch (type) {
        case 1: { // Data Packet
          const seqNum = raw.readUint32BE(1)
          const checksum = raw.readUint32BE(5)
          const dataPacketData = raw.subarray(9);
          const packet = DataPacket.decode(Buffer.from(dataPacketData));

          console.log(`Received Data Packet (seqNum: ${seqNum}, checksum: ${checksum}, data: ${JSON.stringify(packet.toJSON(), null, 4)})`);

          const ackPacket = Buffer.alloc(5);
          ackPacket.writeUInt8(AckType.ACK, 0); // Type 8 for ACK
          ackPacket.writeUInt32BE(seqNum, 1); // Write the sequence number
          socket.send(ackPacket);
          break;
        }

        case 2: {
          const ackSeqNum = raw.readUInt32BE(1)

          // Check if we were waiting for this ACK
          if (pendingAcks.has(ackSeqNum)) {
            const [resolve] = pendingAcks.get(ackSeqNum)!;
            resolve(); // Resolve the pending promise
            pendingAcks.delete(ackSeqNum);
            console.log(`ACK confirmed, removed seqNum ${ackSeqNum} from pending list`);
          } else {
            console.warn(`Received ACK for unknown seqNum: ${ackSeqNum}`);
          }
          break;
        }

        default:
          console.log("Unknown packet type received");
      }
    },
  },
});

// Function to send data with acknowledgment
const sendWithAck = async (data: Uint8Array, requestType: number) => {
  return new Promise<void>((resolve, reject) => {
    // Generate a random sequence number
    const seqNum = Math.floor(Math.random() * 0xFFFFFFFF);

    // Create header buffer
    const header = Buffer.alloc(9);
    header.writeUInt8(requestType, 0);
    header.writeUInt32BE(seqNum, 1); // Write sequence number at byte 1
    const combinedBuffer = Buffer.concat([header, data]);
    let checksum = Bun.hash.crc32(combinedBuffer);
    header.writeUInt32BE(checksum, 5); // Write checksum at byte 5

    const packet = Buffer.concat([header, data]);
    pendingAcks.set(seqNum, [resolve, reject]);
    socket.send(packet);

    setTimeout(() => {
      if (pendingAcks.has(seqNum)) {
        pendingAcks.delete(seqNum);
        reject(new Error(`ACK not received for seqNum: ${seqNum}`));
      }
    }, 5000);
  });
};

// Send LoginRequest
await sendWithAck(
  LoginRequest.encode({
    service: "default_service",
    token: "default_token",
  }).finish(),
  AckType.DATA
);

// Send UpdateRequest
await sendWithAck(
  DataPacket.encode({
    type: 4,
    update: new UpdateRequest({
      name: "test",
      value: "1",
      type: UpdateType.KILLS,
      persistRedis: true,
    })
  }).finish(),
  AckType.DATA
);