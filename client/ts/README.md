# Prism: Go Client

Here is an example on how to use Prism via the built-in Typescript/Javascript client:

```ts
const prism = new Prism("127.0.0.1", 6969, "secret-auth-key-123=============");
await prism.start();

await prism.send(
    LoginRequest.encode({
        service: "default_service",
        token: "default_token",
    }).finish(),
    PacketType.DATA,
);

await prism.send(
    DataPacket.encode({
        type: 4,
        update: new UpdateRequest({
            name: "test",
            value: "1",
            type: UpdateType.KILLS,
            persistRedis: true,
        }),
    }).finish(),
    PacketType.DATA,
);

```