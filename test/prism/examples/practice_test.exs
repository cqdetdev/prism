defmodule Prism.Examples.PracticeTest do
  use ExUnit.Case, async: true

  alias Prism.Examples.{Practice, PracticePayloads, PracticeService}
  alias Prism.Service

  test "practice payload identifiers stay stable" do
    assert PracticePayloads.upsert_player() == 1000
    assert PracticePayloads.player_profile() == 1001
    assert PracticePayloads.leaderboard() == 1002
    assert PracticePayloads.match_result() == "practice_match_result"
    assert PracticePayloads.queue_rating() == "practice_queue_rating"
    assert PracticePayloads.presence() == "practice_presence"
  end

  test "elo delta favors the lower rated upset less than an even match" do
    assert Practice.elo_delta(1000, 1000) == 16
    assert Practice.elo_delta(900, 1300) > Practice.elo_delta(1300, 900)
  end

  test "practice service registers both request and update packet families" do
    spec = Service.spec(PracticeService)

    assert spec.name == "practice_service"
    assert spec.token == "practice_token"
    assert spec.packet_ids == [4, 5]
    assert Enum.any?(spec.routes, &(&1.route == {:request, PracticePayloads.upsert_player()}))
    assert Enum.any?(spec.routes, &(&1.route == {:update, PracticePayloads.match_result()}))
  end
end
