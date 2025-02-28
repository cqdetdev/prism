import Prism from "./Prism";
import DataPacket from "./proto/DataPacket";
import LoginRequest from "./proto/requests/LoginRequest";
import UpdateRequest from "./proto/requests/UpdateRequest";
import { AckType, UpdateType } from "./proto/Types";

const prism = new Prism("127.0.0.1", 7979);
await prism.start();

const addr = prism.getHost(); 
const port = prism.getPort();

await prism.send(
    LoginRequest.encode({
        service: "default_service",
        token: "default_token",
    }).finish(),
    AckType.DATA,
    addr,
    port,
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
    AckType.DATA,
    addr,
    port
);