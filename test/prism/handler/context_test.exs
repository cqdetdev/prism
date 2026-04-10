defmodule Prism.Handler.ContextTest do
  use ExUnit.Case, async: true

  alias Net.Conn
  alias Net.Packet.{Data, Update}
  alias Prism.Handler.Context

  test "decode_json supports update payload values" do
    context =
      Context.new(
        Conn.new("127.0.0.1:9999", true, "practice_service"),
        %Data{
          type: Update.id(),
          payload:
            {:update,
             %Update{
               name: "duel-no-debuff-001",
               value: ~s({"queue":"no_debuff","winner":{"username":"PvPAlpha"}}),
               type: "practice_match_result"
             }}
        },
        {:update, "practice_match_result"}
      )

    assert {:ok, %{"queue" => "no_debuff", "winner" => %{"username" => "PvPAlpha"}}} =
             Context.decode_json(context)
  end
end
