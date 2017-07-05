defmodule Chronik.PubSub.Adapters.Registry do
  @moduledoc """
  Registry adapter for PubSub
  """

  @behaviour Chronik.PubSub

  @name __MODULE__

  # API

  def child_spec(args) do
    Registry.child_spec(keys: :duplicate, name: args[:name] || @name)
  end

  def start_link(args) do
    Registry.start_link(args)
  end

  def subscribe(stream, predicate \\ fn _ -> true end) when is_function(predicate) do
    case Registry.register(@name, stream, predicate) do
      {:ok, _} -> :ok
      {:error, {:already_register, _}} -> {:error, "already_register"}
    end
  end

  def unsubscribe(stream) do
    Registry.unregister(@name, stream)
  end

  def broadcast(stream, events) do
    for event <- events do
      Registry.dispatch(@name, stream,
        &(for {pid, predicate} <- &1, predicate.(event), do: send(pid, event)))
    end
    :ok
  end

end
