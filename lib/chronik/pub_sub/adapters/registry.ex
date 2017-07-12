defmodule Chronik.PubSub.Adapters.Registry do
  @moduledoc false

  @behaviour Chronik.PubSub

  @name __MODULE__

  require Logger

  # API

  def subscribe(stream) do
    Logger.debug ["[#{inspect __MODULE__}<#{inspect stream}>] ",
                  "process: #{inspect self()} subscribed."]
    {:ok, _} = Registry.register(@name, stream, fn _ -> true end)
    :ok
  end

  def subscribe(stream, predicate) when is_function(predicate) do
    Logger.debug ["[#{inspect __MODULE__}<#{inspect stream}>] ",
                  "process: #{inspect self()} subscribed."]
    {:ok, _} = Registry.register(@name, stream, predicate)
    :ok
  end

  def unsubscribe(stream) do
    Logger.debug ["[#{inspect __MODULE__}<#{inspect stream}>] ",
                  "process: #{inspect self()} un-subscribed."]
    Registry.unregister(@name, stream)
  end

  def broadcast(stream, records) do
    Logger.debug ["[#{inspect __MODULE__}<#{inspect stream}>] ",
                  "broadcasting: #{inspect records}"]
    for record <- records do
      Registry.dispatch(@name, stream,
        &(for {pid, predicate} <- &1, predicate.(record), do: send(pid, record)))
    end
    :ok
  end

  def child_spec(args) do
    Registry.child_spec(keys: :duplicate, name: args[:name] || @name)
  end

  def start_link(args) do
    Registry.start_link(args)
  end
end
