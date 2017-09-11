defmodule Example.Application do
  @moduledoc false

  use Application

  alias Example.Projection.{CartsState, Echo}
  alias Example.{Store, PubSub}

  def start(_type, _args) do
    children = [
      {Store, []},
      {PubSub, []},
      {CartsState, []},
      {Echo, []}
    ]

    opts = [strategy: :one_for_one, name: Example.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
