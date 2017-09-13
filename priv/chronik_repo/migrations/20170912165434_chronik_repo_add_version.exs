defmodule Chronik.Repo.Migrations.AddVersion do
  use Ecto.Migration

  def change do
    alter table(:domain_events) do
      add :version, :integer
    end

    create unique_index :domain_events, [:version], unique: true

    execute "UPDATE domain_events SET version = id - 1"
  end
end
