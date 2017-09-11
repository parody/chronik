defmodule Chronik.Store.Adapters.Ecto.Aggregate do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  schema "aggregates" do
    field :aggregate, Chronik.Store.Adapters.Ecto.AtomType
    field :aggregate_id, :string
    field :snapshot_version, :integer
    field :snapshot, :binary
  end

  def changeset(aggregate, params \\ %{}) do
    aggregate
    |> cast(params, [:aggregate, :aggregate_id])
  end
end
