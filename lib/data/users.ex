defmodule Data.Users do
  alias Data.User
  alias Data.Repo
  import Ecto.Query

  def get_user!(username), do: Repo.get_by!(User, username: username)
  def all, do: Repo.all(User)

  def create_user(attrs \\ %{}) do
    %Data.User{}
    |> Data.User.changeset(attrs || %{})
    |> case do
      %Ecto.Changeset{valid?: true} = changeset -> Repo.insert(changeset)
      changeset -> {:error, changeset}
    end
  end

  def all_by_kills do
    query =
      from(u in User,
        order_by: [desc: u.kills]
      )

    Repo.all(query)
  end

  def all_by_deaths do
    query =
      from(u in User,
        order_by: [desc: u.deaths]
      )

    Repo.all(query)
  end

  def all_staff do
    query =
      from(u in User,
        where: fragment("? @> ?", u.roles, ^["staff"])
      )

    Repo.all(query)
  end

  def add_role(username, role) do
    user = Users.get_user!(username)

    updated_roles =
      user.roles
      |> Enum.uniq()
      |> Kernel.++([role])
      |> Enum.uniq()

    user
    |> Ecto.Changeset.change(%{roles: updated_roles})
    |> Repo.update()
  end
end
