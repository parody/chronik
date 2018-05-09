defmodule Chronik.Store.Adapters.Ecto.Aggregate do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Chronik.Store.Adapters.Ecto.Blob

  schema "aggregates" do
    field(:aggregate, Chronik.Store.Adapters.Ecto.AtomType)
    field(:aggregate_id, :string)
    field(:snapshot_version, :integer)
    field(:snapshot, Blob)
  end

  def changeset(aggregate, params \\ %{}) do
    aggregate
    |> cast(params, [:aggregate, :aggregate_id])
  end
end
