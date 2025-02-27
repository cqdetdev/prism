import { Message, Field } from "protobufjs";
import type { UpdateType } from "../Types";

export default class UpdateRequest extends Message<UpdateRequest> {
    @Field.d(1, "string", "required")
    public name!: string;
    @Field.d(2, "string", "required")
    public value!: string | number;
    @Field.d(3, "string", "required")
    public type!: UpdateType;
    @Field.d(4, "bool", "required")
    public persistRedis!: boolean;
  }