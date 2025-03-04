import type { udp } from "bun";
import DataPacket from "./proto/DataPacket";
import { PacketType } from "./proto/Types";
import { createDecipheriv, createCipheriv, randomBytes } from "crypto";

const IV_LENGTH = 12;
const TAG_LENGTH = 16;

export default class Prism {
  private pendingAcks: Map<number, [() => void, () => void]>;
  private socket!: udp.Socket<"buffer">;

  private host: string;
  private port: number;

  private key: Buffer;

  private closed: boolean;

  public constructor(host: string, port: number, key: string) {
    this.pendingAcks = new Map();
    this.host = host;
    this.port = port;
    this.key = Buffer.from(key);
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
      },
    });
  }

  private onData(
    sock: udp.Socket<"buffer">,
    data: Buffer<ArrayBufferLike>
  ): void | Promise<void> {
    const raw = Buffer.from(data);
    if (raw.length < IV_LENGTH + TAG_LENGTH + 9) {
      if (raw[0] == PacketType.ACK) {
        return this.handleAckPacket(raw);
      }
    }

    const iv = raw.subarray(0, IV_LENGTH); 
    const ciphertext = raw.subarray(IV_LENGTH, raw.length - TAG_LENGTH);
    const tag = raw.subarray(raw.length - TAG_LENGTH);

    if (iv.length !== IV_LENGTH || tag.length !== TAG_LENGTH) {
      console.error("Invalid IV or tag length");
      return;
    }

    const dec = this.decrypt(iv, ciphertext, tag);
    if (!dec) {
      console.error("Failed to decrypt data packet");
      return;
    }

    if (dec[0] == PacketType.DATA) {
      return this.handleDataPacket(dec, sock);
    }
  }

  public async send(data: Uint8Array, requestType: number): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      const { iv, ciphertext, tag } = this.encrypt(Buffer.from(data));

      const seq = Math.floor(Math.random() * 0xffffffff);
      const header = Buffer.alloc(9);
      header.writeUInt8(requestType, 0);
      header.writeUInt32BE(seq, 1);
      const combinedBuffer = Buffer.concat([header, data]);
      let checksum = Bun.hash.crc32(combinedBuffer);
      header.writeUInt32BE(checksum, 5);

      const packet = Buffer.concat([header, iv, ciphertext, tag]);
      this.pendingAcks.set(seq, [resolve, reject]);
      // @ts-expect-error
      this.socket.send(packet);

      setTimeout(() => {
        if (this.pendingAcks.has(seq)) {
          this.pendingAcks.delete(seq);
          if (!this.closed) {
            console.error(`ACK not received for seqNum: ${seq}`);
          } else {
            console.error("Socket closed, not sending reject");
          }
        }
      }, 5000);
    });
  }

  private encrypt(data: Uint8Array): {
    iv: Buffer;
    ciphertext: Buffer;
    tag: Buffer;
  } {
    const iv = randomBytes(12);
    const cipher = createCipheriv("aes-256-gcm", this.key, iv);
    const ciphertext = Buffer.concat([cipher.update(data), cipher.final()]);
    const tag = cipher.getAuthTag();
    return { iv, ciphertext, tag };
  }

  private decrypt(iv: Buffer, ciphertext: Buffer, tag: Buffer): Buffer | null {
    try {
      const decipher = createDecipheriv("aes-256-gcm", this.key, iv);
      decipher.setAuthTag(tag);
      const decrypted = Buffer.concat([
        decipher.update(ciphertext),
        decipher.final(),
      ]);
      return decrypted;
    } catch (error) {
      console.log(error);
      return null;
    }
  }

  private handleDataPacket(data: Buffer, sock: udp.Socket<"buffer">) {
    const seq = data.readUInt32BE(1);
    const checksum = data.readUInt32BE(5);
    
    const packet = DataPacket.decode(Buffer.from(data));
    console.log(
      `Received Data Packet (seqNum: ${seq}, checksum: ${checksum}, data: ${JSON.stringify(
        packet.toJSON(),
        null,
        4
      )})`
    );

    const ack = Buffer.alloc(5);
    ack.writeUInt8(PacketType.ACK, 0);
    ack.writeUInt32BE(seq, 1);
    // @ts-expect-error
    sock.send(ack);

    switch (packet.type) {
      case 3:
        this.handleAuthResponse(packet);
        break;
    }
  }

  private handleAckPacket(raw: Buffer) {
    const seq = raw.readUInt32BE(1);

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
