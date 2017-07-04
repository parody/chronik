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

  def subscribe(stream) do
    case Registry.register(@name, stream, nil) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  def broadcast(stream, events) do
    for event <- events do
      Registry.dispatch(@name, stream,
        &(for {pid, _} <- &1, do: send(pid, event)))
    end
    :ok
  end
end
