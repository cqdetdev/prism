import Prism from "./Prism";
import DataPacket from "./proto/DataPacket";
import DataRequest from "./proto/requests/DataRequest";
import LoginRequest from "./proto/requests/LoginRequest";
import { PacketType } from "./proto/Types";

const prism = new Prism("127.0.0.1", 6969, "secret-auth-key-123=============");
prism.start();

await prism.send(
    LoginRequest.encode({
        service: "default_service",
        token: "default_token",
    }).finish(),
    PacketType.DATA,
);

await prism.send(
    DataPacket.encode({
        type: 5,
        request: new DataRequest({
            type: 2,
            payload: JSON.stringify({
                limit: 10
            })
        }),
    }).finish(),
    PacketType.DATA,
);