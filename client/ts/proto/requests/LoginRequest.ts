import { Message, Field } from "protobufjs";

export default class LoginRequest extends Message<LoginRequest> {
    @Field.d(1, "string", "required", "default_service")
    public service!: number;
    @Field.d(2, "string", "required", "default_service")
    public token!: string;
  }
  