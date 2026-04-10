defmodule Prism.Examples.PracticeService do
  @moduledoc false

  use Prism.Service,
    name: "practice_service",
    token: "practice_token",
    login_rate_limit: [max_attempts: 25, window_ms: 60_000]

  alias Prism.Examples.Practice
  alias Prism.Examples.PracticePayloads, as: Payloads
  alias Prism.Handler.Context

  handle_request(Payloads.upsert_player(), :handle_upsert_player, async: false)
  handle_request(Payloads.player_profile(), :handle_player_profile)
  handle_request(Payloads.leaderboard(), :handle_leaderboard)

  handle_update(Payloads.match_result(), :handle_match_result)
  handle_update(Payloads.queue_rating(), :handle_queue_rating)
  handle_update(Payloads.presence(), :handle_presence)

  def handle_upsert_player(context) do
    with {:ok, attrs} <- Context.decode_json(context),
         {:ok, player} <- Practice.upsert_player(attrs) do
      Context.json_reply(context, %{player: player}, message: "PLAYER_UPSERTED")
    else
      {:error, reason} ->
        Context.json_reply(context, %{error: inspect(reason)},
          status: 1,
          message: "PLAYER_UPSERT_FAILED"
        )
    end
  end

  def handle_player_profile(context) do
    with {:ok, attrs} <- Context.decode_json(context),
         {:ok, player} <- Practice.player_profile(attrs) do
      Context.json_reply(context, %{player: player}, message: "PLAYER_PROFILE")
    else
      {:error, reason} ->
        Context.json_reply(context, %{error: inspect(reason)},
          status: 1,
          message: "PLAYER_PROFILE_FAILED"
        )
    end
  end

  def handle_leaderboard(context) do
    with {:ok, attrs} <- Context.decode_json(context),
         {:ok, leaderboard} <-
           Practice.leaderboard(
             Map.get(attrs, "metric", "elo"),
             limit: Map.get(attrs, "limit", 10),
             offset: Map.get(attrs, "offset", 0)
           ) do
      Context.json_reply(context, leaderboard, message: "LEADERBOARD")
    else
      {:error, reason} ->
        Context.json_reply(context, %{error: inspect(reason)},
          status: 1,
          message: "LEADERBOARD_FAILED"
        )
    end
  end

  def handle_match_result(context) do
    with {:ok, attrs} <- Context.decode_json(context),
         {:ok, summary} <- Practice.record_match_result(attrs) do
      Context.broadcast(context, %{event: "practice_match_result", summary: summary})
      Context.json_reply(context, %{match: summary}, message: "MATCH_RECORDED")
    else
      {:error, reason} ->
        Context.json_reply(context, %{error: inspect(reason)},
          status: 1,
          message: "MATCH_RECORD_FAILED"
        )
    end
  end

  def handle_queue_rating(context) do
    with {:ok, attrs} <- Context.decode_json(context),
         {:ok, player} <- Practice.set_queue_rating(attrs) do
      Context.json_reply(context, %{player: player}, message: "QUEUE_RATING_UPDATED")
    else
      {:error, reason} ->
        Context.json_reply(context, %{error: inspect(reason)},
          status: 1,
          message: "QUEUE_RATING_FAILED"
        )
    end
  end

  def handle_presence(context) do
    with {:ok, attrs} <- Context.decode_json(context),
         {:ok, player} <- Practice.record_presence(attrs) do
      Context.json_reply(context, %{player: player}, message: "PRESENCE_RECORDED")
    else
      {:error, reason} ->
        Context.json_reply(context, %{error: inspect(reason)},
          status: 1,
          message: "PRESENCE_FAILED"
        )
    end
  end
end
