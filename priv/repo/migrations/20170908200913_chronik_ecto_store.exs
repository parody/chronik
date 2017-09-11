defmodule Chronik.Store.Adapters.Ecto.Repo.Migrations.CreateTables do
  use Ecto.Migration

  def up do
    create table(:aggregates) do
      add :aggregate, :string, size: 128
      add :aggregate_id, :string, size: 64
      add :snapshot_version, :integer
      add :snapshot, :binary
    end

    create table(:domain_events) do
      add :created, :naive_datetime
      add :domain_event, :binary
      add :aggregate_version, :integer
      add :aggregate_id, :id
      add :domain_event_json, :binary
    end
  end

  def down do
    drop table(:aggregates)
    drop table(:domain_events)
  end
end
