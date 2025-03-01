import type { udp } from "bun";
import DataPacket from "./proto/DataPacket";
import { AckType } from "./proto/Types";

export default class Prism {
  private pendingAcks: Map<number, [() => void, () => void]>;
  private socket!: udp.Socket<"buffer">;

  private host: string;
  private port: number;

  private closed: boolean

  public constructor(host: string, port: number) {
    this.pendingAcks = new Map();
    this.host = host;
    this.port = port;
    this.closed = true;
  }

  public async start() {
    this.closed = false;
    this.socket = await Bun.udpSocket({
      connect: {
        port: this.port,
        hostname: this.host,
      },
      socket: {
        data: this.onData.bind(this),
      }
    });
  }

  private onData(sock: udp.Socket<"buffer">, data: Buffer<ArrayBufferLike>, port: number, addr: string): void | Promise<void> {
    const raw = Buffer.from(data);
    const type = raw[0];

    switch (type) {
      case 1: this.handleDataPacket(raw, sock, addr, port);
      break;
      case 2: this.handleAckPacket(raw, sock, addr, port);
      break;
      default:
        console.log("Unknown packet type received");
    }
  }

  public async send(data: Uint8Array, requestType: number): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      const seqNum = Math.floor(Math.random() * 0xffffffff);
  
      const header = Buffer.alloc(9);
      header.writeUInt8(requestType, 0);
      header.writeUInt32BE(seqNum, 1);
      const combinedBuffer = Buffer.concat([header, data]);
      let checksum = Bun.hash.crc32(combinedBuffer);
      header.writeUInt32BE(checksum, 5);
  
      const packet = Buffer.concat([header, data]);
      this.pendingAcks.set(seqNum, [resolve, reject]);
      // @ts-expect-error
      this.socket.send(packet);
  
      setTimeout(() => {
        if (this.pendingAcks.has(seqNum)) {
          this.pendingAcks.delete(seqNum);
          if (!this.closed) {
            console.error(`ACK not received for seqNum: ${seqNum}`);
          } else {
            console.error("Socket closed, not sending reject");
          }
        }
      }, 5000);
    });
  }

  private handleDataPacket(raw: Buffer, sock: udp.Socket<"buffer">, addr: string, port: number) {
    const seq = raw.readUint32BE(1)
    const checksum = raw.readUint32BE(5)
    const packetData = raw.subarray(9);
    const packet = DataPacket.decode(Buffer.from(packetData));

    console.log(`Received Data Packet (seqNum: ${seq}, checksum: ${checksum}, data: ${JSON.stringify(packet.toJSON(), null, 4)})`);

    const ack = Buffer.alloc(5);
    ack.writeUInt8(AckType.ACK, 0);
    ack.writeUInt32BE(seq, 1)
    // @ts-expect-error
    sock.send(ack);

    switch (packet.type) {
      case 3: this.handleAuthResponse(packet);
      break;
    }
  }

  private handleAckPacket(raw: Buffer, sock: udp.Socket<"buffer">, addr: string, port: number) {
    const seq = raw.readUInt32BE(1)

    if (this.pendingAcks.has(seq)) {
      const [resolve] = this.pendingAcks.get(seq)!;
      resolve();
      this.pendingAcks.delete(seq);
      console.log(`ACK confirmed, removed seqNum ${seq} from pending list`);
    } else {
      console.warn(`Received ACK for unknown seqNum: ${seq}`);
    }
  }

  private handleAuthResponse(packet: DataPacket) {
    const authResponse = packet.authResponse!;
    if (authResponse.status === 1) {
      console.log("Auth failed: ", authResponse.message);
      this.socket.close();
    }
  }

  public getHost(): string {
    return this.host;
  }

  public getPort(): number {
    return this.port;
  }
}
