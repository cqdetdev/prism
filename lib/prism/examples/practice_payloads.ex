defmodule Prism.Examples.PracticePayloads do
  @moduledoc false

  @upsert_player 1000
  @player_profile 1001
  @leaderboard 1002

  @match_result "practice_match_result"
  @queue_rating "practice_queue_rating"
  @presence "practice_presence"

  def upsert_player, do: @upsert_player
  def player_profile, do: @player_profile
  def leaderboard, do: @leaderboard

  def match_result, do: @match_result
  def queue_rating, do: @queue_rating
  def presence, do: @presence
end
