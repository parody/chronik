defmodule Chronik.Aggregate.Supervisor do
  @moduledoc false

  use Supervisor

  @name __MODULE__

  # API

  @doc "Start an aggregate by `id`"
  @spec start_aggregate(aggregate :: atom, String.t) :: {:ok, pid()} | {:error, term()}
  def start_aggregate(aggregate, id) do
    Supervisor.start_child(__MODULE__, [aggregate, id])
  end

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, [], name: @name)
  end

  # Supervisor callbacks

  def init(_opts) do
    child = worker(Chronik.Aggregate, [], restart: :transient)
    supervise([child], strategy: :simple_one_for_one)
  end
end
