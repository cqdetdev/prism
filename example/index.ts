import { Field, Message, OneOf } from "protobufjs";

class LoginRequest extends Message<LoginRequest> {
  @Field.d(1, "string", "required", "default_service")
  public service!: number;
  @Field.d(2, "string", "required", "default_service")
  public token!: string;
}

class UpdateRequest extends Message<UpdateRequest> {
  @Field.d(1, "string", "required")
  public name!: string;
  @Field.d(2, "string", "required")
  public value!: string;
  @Field.d(3, "bool", "required")
  public persist_cache!: boolean;
}

class Packet extends Message<Packet> {
  @Field.d(1, "int32", "required")
  public type!: number;
  
  @Field.d(2, LoginRequest)
  login!: LoginRequest;

  @Field.d(4, UpdateRequest)
  update?: UpdateRequest;

  @OneOf.d("login", "update")
  public payload!: LoginRequest | UpdateRequest;
}



const socket = await Bun.udpSocket({
  connect: {
    port: 6969,
    hostname: '127.0.0.1',
  },
  socket: {
    data(socket, data,) {
      console.log(data);
    },
  }
});

const sent = socket.send(
  LoginRequest.encode({
    service: "default_service",
    token: "default_token",
  }).finish()
);

const sent2 = socket.send(
  Packet.encode({
    type : 4,
    update: new UpdateRequest({
      name: "test",
      value: "test",
      persist_cache: true,
    })
  }).finish()
);
