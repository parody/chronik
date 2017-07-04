defmodule Chronik.Store.Supervisor do
  @moduledoc false

  use Supervisor

  # API

  def start_link(store, adapter, opts) do
    name = Keyword.get(opts, :name, store)
    Supervisor.start_link(__MODULE__, {store, adapter, opts}, name: name)
  end

  # Supervisor callbacks

  def init({store, adapter, opts}) do
    Supervisor.init([
      {adapter, [store, opts]}
    ], strategy: :one_for_one)
  end
end
