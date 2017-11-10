defmodule Chronik.Store.Adapters.Ecto.ChronikRepo.Migrations.MediumBlobForEvent do
  use Ecto.Migration

  # Use a MEDIUMBLOB for domain_events binary and json.
  @blob Chronik.Store.Adapters.Ecto.Blob.type()

  def change do
    alter table(:domain_events) do
        modify :domain_event, @blob
        modify :domain_event_json, @blob
    end
  end
end
