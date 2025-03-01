import { Message, Field, OneOf } from "protobufjs";
import LoginRequest from "./requests/LoginRequest";
import UpdateRequest from "./requests/UpdateRequest";
import AuthResponse from "./responses/AuthResponse";

export default class DataPacket extends Message<DataPacket> {
  @Field.d(1, "int32", "required")
  public type!: number;
  
  @OneOf.d("login", "authResponse", "update")
  public payload!: LoginRequest | AuthResponse |UpdateRequest;

  @Field.d(2, LoginRequest)
  login?: LoginRequest;

  @Field.d(3, AuthResponse)
  authResponse?: AuthResponse;

  @Field.d(4, UpdateRequest)
  update?: UpdateRequest;
}