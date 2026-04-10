import { Message, Field } from "protobufjs";

export default class UpdateRequest extends Message<UpdateRequest> {
    @Field.d(1, "string")
    public name!: string;
    @Field.d(2, "string")
    public value!: string | number;
    @Field.d(3, "string")
    public type!: string;
    @Field.d(4, "bool")
    public persistRedis!: boolean;
  }