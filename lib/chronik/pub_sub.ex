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

  @typedoc "The stream to subscribe from or publish to."
  @type stream :: String.t

  @typedoc "The internal opaque representation of domain events"
  @type events :: Enumerable.t

  # API


  @doc """
  Initialize the domain event bus

  Returns `{:ok, pid}` on success or `{:error, message}` in case of failure.
  """
  @callback start_link(Keyword.t) :: {:ok, pid()} | {:error, String.t}

  @doc """
  Subscribes the caller to the `stream`

  Returns `:ok` on success or `{:error, message}` in case of failure.
  """
  @callback subscribe(stream) :: :ok | {:error, String.t}

  @doc """
  Broadcasts a `events` enumeration to the `stream`

  Returns `:ok` on success or `{:error, message}` in case of failure.
  """
  @callback broadcast(stream, events) :: :ok | {:error, String.t}
end
