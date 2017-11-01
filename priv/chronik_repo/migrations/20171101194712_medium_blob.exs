defmodule Chronik.Store.Adapters.Ecto.ChronikRepo.Migrations.MediumBlob do
  use Ecto.Migration

  # Use a MEDIUMBLOB for Aggregate snapshots.
  @blob Chronik.Store.Adapters.Ecto.Blob.type()

  def change do
    alter table(:aggregates) do
        modify :snapshot, @blob
    end
  end
end
