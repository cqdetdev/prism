import Prism from "./Prism";
import DataPacket from "./proto/DataPacket";
import LoginRequest from "./proto/requests/LoginRequest";
import DataRequest from "./proto/requests/DataRequest";
import UpdateRequest from "./proto/requests/UpdateRequest";
import { PacketType } from "./proto/Types";
import { PracticeRequestType, PracticeUpdateType } from "./practiceProtocol";

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const prism = new Prism("127.0.0.1", 6969, "secret-auth-key-123=============");
prism.start();

await prism.send(
  LoginRequest.encode({
    service: "practice_service",
    token: "practice_token",
  }).finish(),
  PacketType.DATA,
);

await prism.send(
  DataPacket.encode({
    type: 5,
    request: new DataRequest({
      type: PracticeRequestType.upsertPlayer,
      payload: JSON.stringify({
        username: "PvPAlpha",
        xuid: "xuid-alpha",
        display_name: "PvP Alpha",
        region: "NA1",
        language: "en_US",
      }),
    }),
  }).finish(),
  PacketType.DATA,
);

await sleep(150);

await prism.send(
  DataPacket.encode({
    type: 5,
    request: new DataRequest({
      type: PracticeRequestType.upsertPlayer,
      payload: JSON.stringify({
        username: "PvPBeta",
        xuid: "xuid-beta",
        display_name: "PvP Beta",
        region: "NA1",
        language: "en_US",
      }),
    }),
  }).finish(),
  PacketType.DATA,
);

await sleep(150);

await prism.send(
  DataPacket.encode({
    type: 4,
    update: new UpdateRequest({
      name: "duel-no-debuff-001",
      value: JSON.stringify({
        queue: "no_debuff",
        region: "NA1",
        duration_seconds: 180,
        winner: { username: "PvPAlpha", kills: 1, deaths: 0 },
        loser: { username: "PvPBeta", kills: 0, deaths: 1 },
      }),
      type: PracticeUpdateType.matchResult,
      persistRedis: false,
    }),
  }).finish(),
  PacketType.DATA,
);

await sleep(150);

await prism.send(
  DataPacket.encode({
    type: 5,
    request: new DataRequest({
      type: PracticeRequestType.leaderboard,
      payload: JSON.stringify({
        metric: "elo",
        limit: 10,
      }),
    }),
  }).finish(),
  PacketType.DATA,
);
