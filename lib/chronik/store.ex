defmodule Chronik.Store do
  @moduledoc """
  Chronik event Store API
  """

  @typedoc "The options given for reading events from the stream"
  @type options :: Keyword.t

  @typedoc """
  The version of a given event record in the Store.

  A simple implementation is a integer starting from 0. The atom
  `:all` is the initial version (without events yet).
  """
  @type version :: term() | :all

  @typep events :: [Chronik.domain_event]
  @typep event_records :: [Chronik.EventRecord]

  @doc """
  Append a list of events to the Store.

    - `aggregate` is the agregate that generated the events.

    - `events` is an enumberable with the events to append.

    - `options` is a keyword indicating the optimistic concurrency
      checks to perform at the moment of writing to the stream.

  ## Versioning

  Possible values are:

    - `:any`: (default value) no checks are performed, the events are
      always written

    - `:no_stream`: verifies that the target stream does not exists
      yet

    - any other value: the event number expected to currently be at

  The return values are `{:ok, last_inserted_version, records}` on
  success or `{:error, message}` in case of failure.
  """
  @callback append(aggregate :: Chronik.Aggregate,
                      events :: events(),
                        opts :: options()) :: {:ok, version(), event_records()}
                                            | {:error, String.t}

  @doc """
  Retrieves all events from the store starting (but not including) at
  `version`.

  Possible `version` values are `:all` (default value) or a term
  indicating starting read position. Event at `version` is not
  included in the result.

  The return values are `{:ok, version, [event records]}` or `{:error,
  message}` in case of failure.

  If no records are found on the stream (starting at version) the
  function returns `{:ok, version, []}`.
  """
  @callback fetch(version :: version()) :: {:ok, version(), event_records()}
                                         | {:error, String.t}

  @doc """
  Retrieves all events from the store for a given aggregate starting
  (but not including) at `version`.

  Possible `version` values are `:all` (default value) or a term
  indicating starting read position. Event at `version` is not
  included in the result.

  The return values are `{:ok, version, [event records]}` or `{:error,
  message}` in case of failure.

  If no records are found on the stream (starting at version) the
  function returns `{:ok, version, []}`.
  """
  @callback fetch_by_aggregate(aggregate :: Chronik.Aggregate,
                                 version :: version()) :: {:ok, version(), event_records()}
                                                        | {:error, String.t}

  @doc """
  This function allows the Projection module to comapre versions of
  EventRecords coming form the PubSub bus.

  The implementation depends on the version type but a trivial
  implementation is to compare the integers and return the
  corresponding atoms.
  """
  @callback compare_version(version :: version(), version :: version()) :: :past
                                                                         | :next_one
                                                                         | :future
                                                                         | :equal

  @doc """
  This function creates a snapshot in the store for the given
  `aggregate`. The Store only stores the last snapshot.
  """
  @callback snapshot(aggregate :: Chronik.Aggregate,
                         state :: Chronik.Aggregate.state,
                       version :: version()) :: :ok
                                              | {:error, reason() :: String.t}

  @doc """
  Retrives a snapshot from the Store. If there is no snapshot it
  returns `nil`.

  If there is a snapshot this function should return a tuple
  `{version, state}` indicating the state of the snapshot and with
  wich version of the aggregate was created.
  """
  @callback get_snapshot(aggregate :: Chronik.Aggregate) :: {version(), Chronik.Aggregate.state}

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Chronik.Store

      alias Chronik.Store.EventRecord
      alias Chronik.Config

      {_cfg, adapter} = Config.fetch_config(__MODULE__, opts)

      @adapter adapter

      defdelegate append(aggregate, events, opts \\ [version: :any]), to: @adapter
      defdelegate snapshot(aggregate, state, version), to: @adapter
      defdelegate get_snapshot(aggregate), to: @adapter
      defdelegate fetch(version \\ :all), to: @adapter
      defdelegate fetch_by_aggregate(aggregate, version \\ :all), to: @adapter
      defdelegate compare_version(version1, version2), to: @adapter
      defdelegate start_link(opts), to: @adapter
    end
  end

  def start_link(opts \\ []) do
    {store, _pub_sub} = Chronik.Config.fetch_adapters()
    store.start_link(opts)
  end
end
