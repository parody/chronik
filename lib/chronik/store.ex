defmodule Chronik.Store do
  @moduledoc """
  Chronik event store API
  """

  alias Chronik.Store.EventRecord

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Chronik.Store

      {cfg, adapter} = Chronik.Config.fetch_config(__MODULE__, opts)

      @adapter adapter
      @config  cfg

      # API

      def config, do: %{adapter: @adapter, config: @config}

      defdelegate append(stream, events, opts \\ [version: :any]), to: @adapter
      defdelegate fetch(stream, offset \\ 0), to: @adapter

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      def start_link(opts \\ []) do
        Chronik.Store.Supervisor.start_link(__MODULE__, @adapter, opts)
      end

      defoverridable child_spec: 1
    end
  end


  @typedoc "The options given for reading events from the stream"
  @type options :: Keyword.t

  @doc """
  Append a list of events to a stream.

  `stream` is the stream where the events are appended

  `expected_version` indicates the optimistic concurrency checks to
  perform at the moment of writing to the stream.

  `domain_events` an enumberable with the events to append.

  The return values are `:ok` on success or `{:error, message}` in case of failure.

  ## Versioning

  Possible values are:

    - `:any` - no checks are performed, the events are always written
    - `:no_stream` - verifies that the target stream does not exists
      yet
    - any other integer value - the event number expected to currently
      be at
  """
  @callback append(Chronik.stream, [Chronik.event], options) :: {:ok, non_neg_integer}
                                                              | {:error, String.t}

  @doc """
  Read a single event from stream.

  `stream` is the stream to read from.

  Possible `offset` values are :all (default value) or an non negative integer 
  indicating starting read position. Event at `offset` is not included in the result.

  The return values are an event term or `{:error, message}` in case of failure.
  """

  @callback fetch(Chronik.stream, non_neg_integer | atom) :: {:ok, non_neg_integer, [EventRecord.t]}
                                                    | {:error, String.t}
end
