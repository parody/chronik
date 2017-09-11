defmodule Chronik.Application do
  @moduledoc """
  The `Chronik` application only starts up the aggregate Registry.

  The client code is responsible of starting the Store and the PubSub.
  The goal is to let the user include the Store and PubSub in its own
  supervision tree.
  """

  use Application

  @aggregates  Chronik.AggregateRegistry

  def start(_type, _args) do
    children = [
      spec([keys: :unique, name: @aggregates], @aggregates),
      {Chronik.Aggregate.Supervisor, []},
    ]

    opts = [strategy: :one_for_one, name: Chronik.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Internal functions
  defp spec(args, id) do
    Supervisor.child_spec({Registry, args}, id: id)
  end
end
