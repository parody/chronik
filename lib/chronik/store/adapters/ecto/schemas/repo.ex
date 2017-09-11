defmodule Chronik.Store.Adapters.Ecto.Repo do
  @moduledoc false

  use Ecto.Repo, otp_app: :chronik

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
      }
  end

  def get_aggregate({aggregate, id}) do
    alias Chronik.Store.Adapters.Ecto.Aggregate

    case get_by(Aggregate, aggregate: aggregate, aggregate_id: id) do
      nil  -> %Aggregate{aggregate: aggregate, aggregate_id: id}
      a -> a
    end
  end
end
