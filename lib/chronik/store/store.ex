defmodule Chronik.Store do
  @moduledoc """
  Chronik event Store API

  The Store can be configured to store some events on special streams.
  To this end the init/1 function takes a map of struts to stream names.
  For example:
  `@public_topics %{
    CartCreated => "CartsCreated"
  }`
  means that events of the type `%CartCreated{}` generated by any aggregate
  will be stored first in the "CartsCreated" stream and then
  in the aggregate stream.
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

  `events` an enumberable with the events to append.

  `options` is a keyword indicating the optimistic concurrency checks
  to perform at the moment of writing to the stream.

  ## Versioning

  Possible values are:

    - `:any`: (default value) no checks are performed, the events are always written

    - `:no_stream`: verifies that the target stream does not exists
      yet

    - any other integer value: the event number expected to currently
      be at

  The return values are `{:ok, last_inserted_offset, records}` on success or
  `{:error, message}` in case of failure.
  """
  @callback append(stream  :: Chronik.stream,
                   events  :: [Chronik.event],
                   options :: options) :: {:ok, non_neg_integer, [EventRecord.t]} | {:error, String.t}

  @doc """
  Retrieves all events from the stream starting (but not including) at `offset`.

  `stream` is the stream to read from.

  Possible `offset` values are `:all` (default value) or an non negative integer
  indicating starting read position. Event at `offset` is not included in the result.

  The return values are `{:ok, offset, [events]}` or `{:error, message}` in case of failure.
  """
  @callback fetch(stream :: Chronik.stream,
                  offset :: non_neg_integer | :all) :: {:ok, non_neg_integer, [EventRecord.t]}
                                                     | {:error, String.t}
end