defmodule Data.Repo.Migrations.AddPracticeProfileFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add_if_not_exists(:wins, :integer, default: 0, null: false)
      add_if_not_exists(:losses, :integer, default: 0, null: false)
      add_if_not_exists(:matches_played, :integer, default: 0, null: false)
      add_if_not_exists(:elo, :integer, default: 1000, null: false)
      add_if_not_exists(:best_elo, :integer, default: 1000, null: false)
      add_if_not_exists(:current_streak, :integer, default: 0, null: false)
      add_if_not_exists(:best_streak, :integer, default: 0, null: false)
      add_if_not_exists(:queue_ratings, :map, default: %{}, null: false)
      add_if_not_exists(:kit_stats, :map, default: %{}, null: false)
      add_if_not_exists(:practice_metadata, :map, default: %{}, null: false)
      add_if_not_exists(:last_seen_region, :string, default: "", null: false)
    end

    create_if_not_exists(index(:users, [:elo]))
    create_if_not_exists(index(:users, [:wins]))
    create_if_not_exists(index(:users, [:matches_played]))
    create_if_not_exists(index(:users, [:best_streak]))
  end
end
