defmodule Chronik.Store.Adapters.Ecto.DomainEvents do
  @moduledoc false

  use Ecto.Schema

  schema "domain_events" do
    field :aggregate_version, :integer
    field :domain_event, :binary
    field :created, :naive_datetime
    field :aggregate_id, :id
    field :domain_event_json, :string
  end
end
