defmodule Example.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Example.Store, []},
      {Example.PubSub, []},
      {Example.EventProjection, [{Example.Event, "1", &any/1, 0},
                                 {Example.Event, "2", &any/1, 0},
                                 {Example.Event, "3", &any/1, 0}]}
    ]

    opts = [strategy: :one_for_one, name: Example.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp any(_event), do: true
end
