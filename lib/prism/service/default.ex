defmodule Prism.Service.Default do
  @moduledoc false

  use Prism.Service,
    name: "default_service",
    token: "default_token",
    login_rate_limit: [max_attempts: 20, window_ms: 60_000]

  alias Data.Users
  alias Net.Packet.Request
  alias Prism.Handler.Context

  handle_request(Request.create_user(), :handle_create_user)
  handle_request(Request.get_all_users(), :handle_get_all_users)
  handle_request(Request.get_all_staff(), :handle_get_all_staff)
  handle_request(Request.get_ordered_by_kills(), :handle_get_ordered_by_kills)
  handle_request(Request.get_ordered_by_deaths(), :handle_get_ordered_by_deaths)

  def handle_create_user(context) do
    if database_available?() do
      with {:ok, attrs} <- Context.decode_json(context),
           {:ok, user} <- Users.create_user(attrs) do
        Context.json_reply(context, %{user: user.username, xuid: user.xuid},
          message: "USER_CREATED"
        )
      else
        {:error, reason} ->
          Context.json_reply(context, %{error: inspect(reason)},
            status: 1,
            message: "CREATE_USER_FAILED"
          )
      end
    else
      Context.json_reply(context, %{error: "database_disabled"},
        status: 1,
        message: "DATABASE_DISABLED"
      )
    end
  end

  def handle_get_all_users(context) do
    with_database(context, fn -> reply_with_users(context, Users.all(limit_options(context))) end)
  end

  def handle_get_all_staff(context) do
    with_database(context, fn ->
      reply_with_users(context, Users.all_staff(limit_options(context)))
    end)
  end

  def handle_get_ordered_by_kills(context) do
    with_database(context, fn ->
      reply_with_users(context, Users.all_by_kills(limit_options(context)))
    end)
  end

  def handle_get_ordered_by_deaths(context) do
    with_database(context, fn ->
      reply_with_users(context, Users.all_by_deaths(limit_options(context)))
    end)
  end

  defp reply_with_users(context, users) do
    payload =
      Enum.map(users, fn user ->
        %{
          username: user.username,
          display_name: user.display_name,
          kills: user.kills,
          deaths: user.deaths,
          roles: user.roles
        }
      end)

    Context.json_reply(context, %{users: payload}, message: "USERS_OK")
  end

  defp limit_options(context) do
    case Context.decode_json(context) do
      {:ok, %{"limit" => limit, "offset" => offset}} ->
        [limit: normalize_integer(limit), offset: normalize_integer(offset)]

      {:ok, %{"limit" => limit}} ->
        [limit: normalize_integer(limit)]

      _ ->
        []
    end
  end

  defp normalize_integer(value) when is_integer(value), do: value
  defp normalize_integer(value) when is_float(value), do: trunc(value)
  defp normalize_integer(value) when is_binary(value), do: String.to_integer(value)

  defp with_database(context, fun) do
    if database_available?() do
      fun.()
    else
      Context.json_reply(context, %{error: "database_disabled"},
        status: 1,
        message: "DATABASE_DISABLED"
      )
    end
  end

  defp database_available? do
    Process.whereis(Data.Repo) != nil
  end
end
