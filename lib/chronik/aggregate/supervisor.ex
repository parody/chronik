defmodule Chronik.Aggregate.Supervisor do
  @moduledoc false

  use Supervisor

  @name __MODULE__

  # API

  @doc "Start an aggregate by `id`"
  @spec start_aggregate(String.t) :: {:ok, pid()} | {:error, term()}
  def start_aggregate(id) do
    Supervisor.start_child(__MODULE__, [id])
  end

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: @name)
  end

  # Supervisor callbacks

  def init(_args) do
    child = worker(Chronik.Event, [], restart: :transient)
    supervise([child], strategy: :simple_one_for_one)
  end
end
