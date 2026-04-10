defmodule Data.Repo.Migrations.AddUserPerformanceIndexes do
  use Ecto.Migration

  def change do
    create_if_not_exists(unique_index(:users, [:username]))
    create_if_not_exists(index(:users, [:kills]))
    create_if_not_exists(index(:users, [:deaths]))
    create_if_not_exists(index(:users, [:roles], using: :gin))
  end
end
