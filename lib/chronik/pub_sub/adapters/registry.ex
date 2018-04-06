defmodule Chronik.PubSub.Adapters.Registry do
  @moduledoc false

  require Logger

  require Chronik.Utils

  alias Chronik.Utils

  @behaviour Chronik.PubSub

  @name __MODULE__

  @spec child_spec(Keyword.t | map()) :: map()
  def child_spec(args) do
    Registry.child_spec(keys: :duplicate, name: args[:name] || @name)
  end

  def start_link(_opts) do
    Registry.start_link([keys: :duplicate, name: @name])
  end

  @spec subscribe(opts :: Keyword.t) :: :ok
  def subscribe(opts \\ []) do
    # See the consistency type given by the subscriber. By default
    # the subscription is eventual.
    consistency = Keyword.get(opts, :consistency, :eventual)

    Utils.debug("#{inspect self()} #{consistency} subscribed.")

    # There is only one stream (:stream_all). We store the type of
    # consistency on the registry as the metadata.
    {:ok, _} = Registry.register(@name, :stream_all, [consistency: consistency])
    :ok
  end

  @spec unsubscribe :: :ok
  def unsubscribe do
    Utils.debug("#{inspect self()} un-subscribed.")

    # Unregister the process from the stream_all.
    Registry.unregister(@name, :stream_all)
  end

  @spec broadcast(records :: [Chronik.EventRecord]) :: :ok
  def broadcast(records) do
    Utils.debug("broadcasting: #{inspect records}")

    for record <- records do
      Registry.dispatch(@name, :stream_all,
        &(for {pid, opts} <- &1 do
            # Check the consistency type of the subscriber. If the
            # consistency is :eventual we send a normal message, if
            # it is :strict then we do a synchronous call
            case Keyword.fetch!(opts, :consistency) do
              :eventual ->
                send(pid, record)
              :strict ->
                case GenServer.call(pid, {:process, record}) do
                  :ok -> :ok
                  _ ->
                    Utils.warn("the #{inspect pid} projection replied " <>
                                "a non :ok result.")
                end
            end
          end))
    end

    :ok
  end
end
