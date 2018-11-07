defmodule Chronik.Store.Adapters.Ecto.Blob do
  @moduledoc false

  @behaviour Ecto.Type

  alias Chronik.Store.Adapters.Ecto.ChronikRepo

  def type do
    case Application.get_env(:chronik, ChronikRepo)[:adapter] do
      Ecto.Adapters.Postgres ->
        :bytea

      _ ->
        :MEDIUMBLOB
    end
  end

  def load(blob), do: {:ok, blob}

  def dump(blob), do: {:ok, blob}

  def cast(binary), do: {:ok, binary}
end
