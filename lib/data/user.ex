defmodule Data.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:xuid, :string, default: "")
    field(:username, :string, default: "")
    field(:display_name, :string, default: "")

    field(:whitelisted, :boolean, default: false)

    field(:kills, :integer, default: 0)
    field(:deaths, :integer, default: 0)

    field(:discord_id, :string, default: "")
    field(:link_code, :string, default: "")

    field(:staff_mode, :boolean, default: false)
    field(:vanished, :boolean, default: false)

    field(:address, :string, default: "")
    field(:device_id, :string, default: "")
    field(:self_signed_id, :string, default: "")

    field(:roles, {:array, :string}, default: [])
    field(:tags, {:array, :map}, default: [])

    field(:language, :string, default: "")

    field(:playtime, :integer, default: 0)

    field(:frozen, :boolean, default: false)

    field(:last_message_from, :string, default: "")

    timestamps()
  end

  def changeset(user, params \\ %{}) do
    user
    |> cast(params, [
      :xuid,
      :username,
      :display_name,
      :whitelisted,
      :kills,
      :deaths,
      :discord_id,
      :link_code,
      :staff_mode,
      :vanished,
      :address,
      :device_id,
      :self_signed_id,
      :roles,
      :tags,
      :language,
      :playtime,
      :frozen,
      :last_message_from
    ])
    |> validate_required([:username, :xuid])
  end
end
