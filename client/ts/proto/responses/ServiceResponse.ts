import { Message, Field } from "protobufjs";

export default class ServiceResponse extends Message<ServiceResponse> {
  @Field.d(1, "int32")
  public status!: number;

  @Field.d(2, "string")
  public message!: string;

  @Field.d(3, "string")
  public payload!: string;
}
