import { Message, Field, OneOf } from "protobufjs";
import LoginRequest from "./requests/LoginRequest";
import UpdateRequest from "./requests/UpdateRequest";

export default class DataPacket extends Message<DataPacket> {
    @Field.d(1, "int32", "required")
    public type!: number;
    
    @Field.d(2, LoginRequest)
    login?: LoginRequest;
  
    @Field.d(4, UpdateRequest)
    update?: UpdateRequest;
  
    @OneOf.d("login", "update")
    public payload!: LoginRequest | UpdateRequest;
  }