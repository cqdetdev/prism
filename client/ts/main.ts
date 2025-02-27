import Oomf from "./Oomf";
import DataPacket from "./proto/DataPacket";
import LoginRequest from "./proto/requests/LoginRequest";
import UpdateRequest from "./proto/requests/UpdateRequest";
import { AckType, UpdateType } from "./proto/Types";

const oomf = new Oomf("127.0.0.1", 6969);
await oomf.start();

const addr = oomf.getHost(); 
const port = oomf.getPort();

await oomf.send(
    LoginRequest.encode({
        service: "default_service",
        token: "default_token",
    }).finish(),
    AckType.DATA,
    addr,
    port,
);

await oomf.send(
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