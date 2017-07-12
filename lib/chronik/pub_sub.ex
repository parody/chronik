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

  @doc """
  Initialize the domain event bus

  Returns `{:ok, pid}` on success or `{:error, message}` in case of
  failure.
  """
  @callback start_link(Keyword.t) :: {:ok, pid()} | {:error, String.t}

  @doc """
  Subscribes the caller to the `stream`

  Multiple subscriptions to the same `stream` are allowed. The
  subscriber will receive the events multiple times.

  Returns `:ok` on success or `{:error, message}` in case of failure.
  """
  @callback subscribe(stream :: Chronik.stream) :: Chronik.result_status


  @doc """
  Subscribes the caller to the `stream` filtering out
  events that do not satisfy the `predicate`.

  Multiple subscriptions to the same `stream` are allowed. The
  subscriber will receive the events multiple times.

  Returns `:ok` on success or `{:error, message}` in case of failure.
  """
  @callback subscribe(stream    :: Chronik.stream,
                      predicate :: Chronik.predicate) :: Chronik.result_status

  @doc """
  Unsubscribes the caller from the `stream`. No further events should
  be received from this stream. Note: events from the stream could
  still be on the mailbox.

  Returns `:ok` on succes or `{:error, message}` in case of failure.
  """
  @callback unsubscribe(stream :: Chronik.stream) :: Chronik.result_status

  @doc """
  Broadcasts a list of `records` enumeration to the `stream`

  Returns `:ok` on success or `{:error, message}` in case of failure.
  """
  @callback broadcast(stream :: Chronik.stream,
                      records :: EventRecord.t) :: Chronik.result_status
end
