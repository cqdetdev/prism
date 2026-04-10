import { Message, Field } from "protobufjs";

export default class LoginRequest extends Message<LoginRequest> {
    @Field.d(1, "string")
    public service!: string;
    @Field.d(2, "string")
    public token!: string;
  }
  