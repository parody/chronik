defmodule Chronik.Store.Adapters.Ecto.ChronikRepo.Migrations.BigintForVersion do
  use Ecto.Migration

  def change do
    alter table(:aggregates) do
      modify :snapshot_version, :bigint
    end

    alter table(:domain_events) do
      modify :aggregate_version, :bigint
      modify :version, :bigint
    end
  end
end
