defmodule Chronik.PubSub do
  @moduledoc """
  PubSub adapter contract.
  """

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Chronik.PubSub

      {cfg, adapter} = Chronik.Config.fetch_config(__MODULE__, opts)

      @adapter adapter
      @config  cfg

      # API

      def config, do: %{adapter: @adapter, config: @config}

      defdelegate subscribe(stream), to: @adapter
      defdelegate subscribe(stream, predicate), to: @adapter
      defdelegate unsubscribe(stream), to: @adapter
      defdelegate broadcast(stream, events), to: @adapter

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      def start_link(opts \\ []) do
        Chronik.PubSub.Supervisor.start_link(__MODULE__, @adapter, opts)
      end

      defoverridable child_spec: 1
    end
  end

  @typedoc "The result status of all operations on the pub_sub"
  @type result_status :: :ok | {:error, String.t}

  @doc """
  Initialize the domain event bus.

  Returns `{:ok, pid}` on success or `{:error, message}` in case of
  failure.
  """
  @callback start_link(options :: Keyword.t) :: {:ok, pid()} | {:error, String.t}

  @doc """
  Subscribes the caller to the `stream`.

  Multiple subscriptions to the same `stream` are allowed. The
  subscriber will receive the events multiple times.

  Returns `:ok` on success or `{:error, message}` in case of failure.
  """
  @callback subscribe(stream :: Chronik.stream) :: Chronik.Pubsub.result_status

  @typedoc "This is a boolean predicate that is used for filtering events in the bus"
  @type predicate :: fun((term() -> boolean()))

  @doc """
  Subscribes the caller to the `stream` filtering out
  events that do not satisfy the `predicate`.

  Multiple subscriptions to the same `stream` are allowed. The
  subscriber will receive the events multiple times.

  Returns `:ok` on success or `{:error, message}` in case of failure.
  """
  @callback subscribe(stream    :: Chronik.stream,
                      predicate :: Chronik.predicate) :: Chronik.Pubsub.result_status

  @doc """
  Unsubscribes the caller from the `stream`. No further events are
  received from this stream. Note: events from the stream could
  still be on the mailbox.

  Returns `:ok` on succes or `{:error, message}` in case of failure.
  """
  @callback unsubscribe(stream :: Chronik.stream) :: Chronik.Pubsub.result_status

  @doc """
  Broadcasts an enumeration of `records` to all the subscribers.

  Returns `:ok` on success or `{:error, message}` in case of failure.
  """
  @callback broadcast(stream :: Chronik.stream, records :: EventRecord.t) :: Chronik.Pubsub.result_status
end