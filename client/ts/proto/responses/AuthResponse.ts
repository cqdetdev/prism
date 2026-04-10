import { Message, Field } from "protobufjs";

export default class AuthResponse extends Message<AuthResponse> {
    @Field.d(1, "int32")
    public status!: number;
    @Field.d(2, "string")
    public message!: string;
}
  