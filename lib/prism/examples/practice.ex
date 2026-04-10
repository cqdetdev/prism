defmodule Prism.Examples.Practice do
  @moduledoc false

  import Ecto.Query

  alias Data.{Repo, User}

  @default_elo 1000
  @leaderboard_metrics %{
    "elo" => :elo,
    "wins" => :wins,
    "kills" => :kills,
    "streak" => :best_streak
  }

  def database_available? do
    Process.whereis(Data.Repo) != nil
  end

  def upsert_player(attrs) when is_map(attrs) do
    if database_available?() do
      attrs = build_player_attrs(attrs)
      existing = lookup_player(attrs)
      player = existing || %User{}

      player
      |> User.changeset(attrs)
      |> Repo.insert_or_update()
      |> case do
        {:ok, user} -> {:ok, serialize_user(user)}
        {:error, changeset} -> {:error, changeset}
      end
    else
      {:error, :database_disabled}
    end
  end

  def player_profile(attrs) when is_map(attrs) do
    if database_available?() do
      case lookup_player(attrs) do
        %User{} = user -> {:ok, serialize_user(user)}
        nil -> {:error, :player_not_found}
      end
    else
      {:error, :database_disabled}
    end
  end

  def leaderboard(metric, opts \\ []) do
    if database_available?() do
      case Map.fetch(@leaderboard_metrics, to_string(metric)) do
        {:ok, field_name} ->
          limit = normalize_integer(Keyword.get(opts, :limit, 10), 10)
          offset = normalize_integer(Keyword.get(opts, :offset, 0), 0)

          query =
            from(u in User,
              order_by: [desc: field(u, ^field_name)],
              limit: ^limit,
              offset: ^offset
            )

          {:ok,
           %{
             metric: to_string(metric),
             entries: Repo.all(query) |> Enum.map(&serialize_user/1)
           }}

        :error ->
          {:error, :invalid_metric}
      end
    else
      {:error, :database_disabled}
    end
  end

  def record_match_result(attrs) when is_map(attrs) do
    if database_available?() do
      winner_attrs = value(attrs, :winner, %{})
      loser_attrs = value(attrs, :loser, %{})
      queue = value(attrs, :queue, "global")
      region = value(attrs, :region, "")
      duration_seconds = normalize_integer(value(attrs, :duration_seconds, 0), 0)

      with %User{} = winner <- lookup_player(winner_attrs),
           %User{} = loser <- lookup_player(loser_attrs) do
        if winner.id == loser.id do
          {:error, :invalid_match_result}
        else
          Repo.transaction(fn ->
            winner_kills = normalize_integer(value(winner_attrs, :kills, 1), 1)
            winner_deaths = normalize_integer(value(winner_attrs, :deaths, 0), 0)
            loser_kills = normalize_integer(value(loser_attrs, :kills, 0), 0)
            loser_deaths = normalize_integer(value(loser_attrs, :deaths, 1), 1)

            winner_queue_rating = queue_rating(winner, queue)
            loser_queue_rating = queue_rating(loser, queue)
            delta = elo_delta(winner_queue_rating, loser_queue_rating)

            winner_updated =
              winner
              |> User.changeset(%{
                wins: winner.wins + 1,
                matches_played: winner.matches_played + 1,
                kills: winner.kills + winner_kills,
                deaths: winner.deaths + winner_deaths,
                elo: winner.elo + delta,
                best_elo: max(winner.best_elo, winner.elo + delta),
                current_streak: winner.current_streak + 1,
                best_streak: max(winner.best_streak, winner.current_streak + 1),
                queue_ratings:
                  put_queue_rating(winner.queue_ratings, queue, winner_queue_rating + delta),
                kit_stats:
                  update_kit_stats(winner.kit_stats, queue, :win, winner_kills, winner_deaths),
                playtime: winner.playtime + duration_seconds,
                last_seen_region: region,
                practice_metadata:
                  merge_metadata(winner.practice_metadata, %{
                    "last_queue" => queue,
                    "last_result" => "win"
                  })
              })
              |> Repo.update!()

            loser_updated =
              loser
              |> User.changeset(%{
                losses: loser.losses + 1,
                matches_played: loser.matches_played + 1,
                kills: loser.kills + loser_kills,
                deaths: loser.deaths + loser_deaths,
                elo: max(loser.elo - delta, 0),
                best_elo: loser.best_elo,
                current_streak: 0,
                queue_ratings:
                  put_queue_rating(loser.queue_ratings, queue, max(loser_queue_rating - delta, 0)),
                kit_stats:
                  update_kit_stats(loser.kit_stats, queue, :loss, loser_kills, loser_deaths),
                playtime: loser.playtime + duration_seconds,
                last_seen_region: region,
                practice_metadata:
                  merge_metadata(loser.practice_metadata, %{
                    "last_queue" => queue,
                    "last_result" => "loss"
                  })
              })
              |> Repo.update!()

            %{
              queue: queue,
              region: region,
              duration_seconds: duration_seconds,
              elo_delta: delta,
              winner: serialize_user(winner_updated),
              loser: serialize_user(loser_updated)
            }
          end)
          |> case do
            {:ok, result} -> {:ok, result}
            {:error, reason} -> {:error, reason}
          end
        end
      else
        _ -> {:error, :player_not_found}
      end
    else
      {:error, :database_disabled}
    end
  end

  def set_queue_rating(attrs) when is_map(attrs) do
    if database_available?() do
      queue = value(attrs, :queue)
      rating = normalize_integer(value(attrs, :rating, @default_elo), @default_elo)
      region = value(attrs, :region, "")

      cond do
        is_nil(queue) ->
          {:error, :invalid_queue}

        player = lookup_player(attrs) ->
          player
          |> User.changeset(%{
            queue_ratings: put_queue_rating(player.queue_ratings, queue, rating),
            best_elo: max(player.best_elo, rating),
            last_seen_region: if(region == "", do: player.last_seen_region, else: region),
            practice_metadata:
              merge_metadata(player.practice_metadata, %{
                "last_queue" => queue,
                "queue_rating_source" => "manual"
              })
          })
          |> Repo.update()
          |> case do
            {:ok, user} -> {:ok, serialize_user(user)}
            {:error, changeset} -> {:error, changeset}
          end

        true ->
          {:error, :player_not_found}
      end
    else
      {:error, :database_disabled}
    end
  end

  def record_presence(attrs) when is_map(attrs) do
    if database_available?() do
      with %User{} = player <- lookup_player(attrs) do
        display_name = value(attrs, :display_name, player.display_name)
        region = value(attrs, :region, player.last_seen_region)
        playtime_delta = normalize_integer(value(attrs, :playtime_delta, 0), 0)
        metadata = value(attrs, :practice_metadata, %{})

        player
        |> User.changeset(%{
          display_name: display_name,
          device_id: value(attrs, :device_id, player.device_id),
          language: value(attrs, :language, player.language),
          playtime: player.playtime + playtime_delta,
          last_seen_region: region,
          practice_metadata: merge_metadata(player.practice_metadata, metadata)
        })
        |> Repo.update()
        |> case do
          {:ok, updated} -> {:ok, serialize_user(updated)}
          {:error, changeset} -> {:error, changeset}
        end
      else
        _ ->
          upsert_player(attrs)
      end
    else
      {:error, :database_disabled}
    end
  end

  def elo_delta(winner_rating, loser_rating, k_factor \\ 32) do
    expected =
      1.0 /
        (1.0 +
           :math.pow(
             10,
             (normalize_integer(loser_rating, @default_elo) -
                normalize_integer(winner_rating, @default_elo)) / 400
           ))

    max(1, round(k_factor * (1.0 - expected)))
  end

  def serialize_user(%User{} = user) do
    %{
      username: user.username,
      xuid: user.xuid,
      display_name: user.display_name,
      kills: user.kills,
      deaths: user.deaths,
      wins: user.wins,
      losses: user.losses,
      matches_played: user.matches_played,
      elo: user.elo,
      best_elo: user.best_elo,
      current_streak: user.current_streak,
      best_streak: user.best_streak,
      playtime: user.playtime,
      last_seen_region: user.last_seen_region,
      queue_ratings: user.queue_ratings || %{},
      kit_stats: user.kit_stats || %{},
      practice_metadata: user.practice_metadata || %{}
    }
  end

  defp lookup_player(attrs) do
    cond do
      xuid = value(attrs, :xuid) -> Repo.get_by(User, xuid: xuid)
      username = value(attrs, :username) -> Repo.get_by(User, username: username)
      true -> nil
    end
  end

  defp build_player_attrs(attrs) do
    %{
      xuid: value(attrs, :xuid),
      username: value(attrs, :username),
      display_name: value(attrs, :display_name, value(attrs, :username, "")),
      device_id: value(attrs, :device_id, ""),
      language: value(attrs, :language, ""),
      last_seen_region: value(attrs, :last_seen_region, value(attrs, :region, "")),
      practice_metadata: value(attrs, :practice_metadata, %{})
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp value(map, key, default \\ nil) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp normalize_integer(value, _default) when is_integer(value), do: value
  defp normalize_integer(value, _default) when is_float(value), do: trunc(value)

  defp normalize_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp normalize_integer(_value, default), do: default

  defp queue_rating(%User{} = user, queue) do
    user.queue_ratings
    |> Map.get(queue)
    |> normalize_integer(user.elo || @default_elo)
  end

  defp put_queue_rating(queue_ratings, queue, rating) when is_map(queue_ratings) do
    Map.put(queue_ratings, queue, rating)
  end

  defp put_queue_rating(_queue_ratings, queue, rating) do
    %{queue => rating}
  end

  defp update_kit_stats(kit_stats, queue, result, kills, deaths) when is_map(kit_stats) do
    stats =
      kit_stats
      |> Map.get(queue, %{})
      |> Map.put(
        "matches",
        normalize_integer(Map.get(Map.get(kit_stats, queue, %{}), "matches"), 0) + 1
      )
      |> Map.put(
        "kills",
        normalize_integer(Map.get(Map.get(kit_stats, queue, %{}), "kills"), 0) + kills
      )
      |> Map.put(
        "deaths",
        normalize_integer(Map.get(Map.get(kit_stats, queue, %{}), "deaths"), 0) + deaths
      )
      |> Map.update(to_string(result), 1, &(normalize_integer(&1, 0) + 1))

    Map.put(kit_stats, queue, stats)
  end

  defp update_kit_stats(_kit_stats, queue, result, kills, deaths) do
    update_kit_stats(%{}, queue, result, kills, deaths)
  end

  defp merge_metadata(current, incoming) when is_map(current) and is_map(incoming),
    do: Map.merge(current, incoming)

  defp merge_metadata(current, _incoming) when is_map(current), do: current
  defp merge_metadata(_current, incoming) when is_map(incoming), do: incoming
  defp merge_metadata(_current, _incoming), do: %{}
end
