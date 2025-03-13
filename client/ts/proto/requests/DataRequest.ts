import { Message, Field } from "protobufjs";

export default class DataRequest extends Message<DataRequest> {
    @Field.d(1, "int32", "required")
    public type!: number;
    @Field.d(2, "string", "required")
    public payload!: string
  }