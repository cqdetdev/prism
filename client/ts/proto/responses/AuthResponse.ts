import { Message, Field } from "protobufjs";

export default class AuthResponse extends Message<AuthResponse> {
    @Field.d(1, "int32", "required")
    public status!: number;
    @Field.d(2, "string", "required", "default_service")
    public message!: string;
}
  