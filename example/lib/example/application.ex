defmodule Example.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Example.Store, []},
      {Example.PubSub, []},
      {Example.CartState, [{Example.Cart, "4", :all}]}
    ]

    opts = [strategy: :one_for_one, name: Example.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
