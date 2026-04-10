import { Message, Field } from "protobufjs";

export default class DataRequest extends Message<DataRequest> {
    @Field.d(1, "int32")
    public type!: number;
    @Field.d(2, "string")
    public payload!: string
  }