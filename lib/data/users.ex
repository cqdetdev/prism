defmodule Data.Users do
  alias Data.User
  alias Data.Repo
  import Ecto.Query

  @default_limit 100
  @max_limit 500

  def get_user!(username), do: Repo.get_by!(User, username: username)
  def all(opts \\ []), do: User |> paginate(opts) |> Repo.all()

  def create_user(attrs \\ %{}) do
    %Data.User{}
    |> Data.User.changeset(attrs || %{})
    |> case do
      %Ecto.Changeset{valid?: true} = changeset -> Repo.insert(changeset)
      changeset -> {:error, changeset}
    end
  end

  def all_by_kills(opts \\ []) do
    query =
      from(u in User,
        order_by: [desc: u.kills]
      )

    query
    |> paginate(opts)
    |> Repo.all()
  end

  def all_by_deaths(opts \\ []) do
    query =
      from(u in User,
        order_by: [desc: u.deaths]
      )

    query
    |> paginate(opts)
    |> Repo.all()
  end

  def all_staff(opts \\ []) do
    query =
      from(u in User,
        where: fragment("? @> ?", u.roles, ^["staff"])
      )

    query
    |> paginate(opts)
    |> Repo.all()
  end

  def add_role(username, role) do
    user = get_user!(username)

    updated_roles =
      user.roles
      |> Enum.uniq()
      |> Kernel.++([role])
      |> Enum.uniq()

    user
    |> Ecto.Changeset.change(%{roles: updated_roles})
    |> Repo.update()
  end

  defp paginate(query, opts) do
    limit =
      opts
      |> Keyword.get(:limit, @default_limit)
      |> min(@max_limit)
      |> max(1)

    offset = max(Keyword.get(opts, :offset, 0), 0)

    from(q in query, limit: ^limit, offset: ^offset)
  end
end
