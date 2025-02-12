import { Field, Message } from "protobufjs";
class LoginRequest extends Message<LoginRequest> {
  @Field.d(1, "string", "required", "default_service")
  public service!: string;
  @Field.d(2, "string", "required", "default_service")
  public token!: string;
}

const socket = await Bun.connect({
    hostname: "localhost",
    port: 6969,
    
  
    socket: {
      data(socket, data) {
        console
      },
      open(socket) {
        const msg = new LoginRequest({
          service: "pm-server",
          token: "test",
        })
        socket.setNoDelay(true)

        const buffer = LoginRequest.encode(msg).finish();
        console.log(Buffer.from(buffer).length);
        const written = socket.write(Buffer.from(buffer));
        console.log(written);
      },
      close(socket) {},
      drain(socket) {},
      error(socket, error) {
        console.log(error);
      },
  
      // client-specific handlers
      connectError(socket, error) {}, // connection failed
      end(socket) {}, // connection closed by server
      timeout(socket) {}, // connection timed out
    },
  });

