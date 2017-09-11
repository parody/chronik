defmodule Chronik.Projection.Supervisor do
  @moduledoc false

  use Supervisor

  # API
  def start_link(mod, children) do
    name = Module.concat([mod, Supervisor])
    Supervisor.start_link(__MODULE__, children, name: name)
  end

  # Supervisor callbacks
  def init(children) do
    Supervisor.init(children, strategy: :one_for_all)
  end
end
