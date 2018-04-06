defmodule Chronik.Application do
  @moduledoc false

  use Application

  @aggregates Chronik.AggregateRegistry

  def start(_type, _args) do
    children = [
      spec([keys: :unique, name: @aggregates], @aggregates),
      Chronik.Aggregate.Supervisor,
    ]

    opts = [strategy: :one_for_one, name: Chronik.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Internal functions

  defp spec(args, id) do
    Supervisor.child_spec({Registry, args}, id: id)
  end
end
