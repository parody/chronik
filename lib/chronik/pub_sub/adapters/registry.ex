defmodule Chronik.PubSub.Adapters.Registry do
  @moduledoc """
  This module is an adapter for the PubSub.

  It is based on the Registry.
  """
  require Logger

  @behaviour Chronik.PubSub
  @name __MODULE__

  @doc false
  def child_spec(args) do
    Registry.child_spec(keys: :duplicate, name: args[:name] || @name)
  end

  @doc false
  def start_link(args) do
    Registry.start_link(args)
  end

  @spec subscribe(opts :: Keyword.t) :: :ok
  def subscribe(opts \\ []) do
    # See the consistency type given by the subscriber.
    # By default the subscription is eventual.
    consistency = Keyword.get(opts, :consistency, :eventual)
    log("#{inspect self()} #{consistency} subscribed.")
    # There is only one stream (:stream_all).
    # We store the type of consistency on the registry as the metadata.
    {:ok, _} = Registry.register(@name, :stream_all, [consistency: consistency])
    :ok
  end

  @doc "Unregister the process from the Registry."
  @spec unsubscribe :: :ok
  def unsubscribe do
    log("#{inspect self()} un-subscribed.")
    # Unregister the process from the stream_all.
    Registry.unregister(@name, :stream_all)
  end

  @doc "Broadcast the records to all the subribers."
  @spec broadcast(records :: [Chronik.EventRecord]) :: :ok
  def broadcast(records) do
    log("broadcasting: #{inspect records}")
    for record <- records do
      Registry.dispatch(@name, :stream_all,
        &(for {pid, opts} <- &1 do
            # Check the consistency type of the subscriber.
            case Keyword.fetch!(opts, :consistency) do
              # If the consistency is :eventual send a message.
              :eventual -> send(pid, record)
              # If it is :strict do a synchronous call.
              :strict -> :ok = GenServer.call(pid, {:process, record})
            end
          end))
    end
    :ok
  end

  defp log(msg) do
    Logger.debug(fn -> "[#{inspect __MODULE__}] #{msg}" end)
  end
end
