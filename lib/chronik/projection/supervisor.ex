defmodule Chronik.Projection.Supervisor do
  use Supervisor

  alias Chronik.Projection
  alias Chronik.Projection.Consumer

  def init(projection_id) do
    children = [
      {Projection, []},
      {Consumer, []}
    ]
    supervise(children, strategy: :one_for_all)
  end
end