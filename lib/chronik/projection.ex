defmodule Chronik.Projection do
  @moduledoc """
  `Chronik.Projection` is a read-only model connected to `Chronik.PubSub`

  Client code has to implement the `Chronik.Projection.init/1` function
  and the state transition `Chronik.Projection.handle_event/2`.

  ## Example

  ```
  defmodule DomainEvents do
    defmodule CounterCreated do
      defstruct [:id]
    end

    defmodule CounterIncremented do
      defstruct [:id, :increment]
    end
  end

  defmodule CounterState do
    @behaviour Chronik.Projection

    alias DomainEvents.CounterCreated
    alias DomainEvents.CounterIncremented
    alias Chronik.Projection

    def start_link(opts), do: Projection.start_link(__MODULE__, opts)

    def init(_opts), do: {nil, []}

    def handle_event(%CounterCreated{}, nil) do
      0
    end
    def handle_event(%CounterIncremented{increment: increment}, value) do
      value + increment
    end
  end
  ```
  """

  @typedoc "The `state` represents the state of an projection."
  @type state :: term()

  # Callbacks

  @doc """
  The `init` function defines the intial state of an projection and
  some options.

  The accepted `options`:

    * `:version` start replaying events from `version` and up. `:all`
      indicates that the replay should be from the begining of times while
      `:current` means that no re-play should be made and start feeding domain
      events from current version and on.

    * `:consistency` indicates how the projection should subscribe to
      the `Chronik.PubSub`. Possible values are `:eventual` (default) and
      `:strict`.
  """
  @callback init(opts :: Keyword.t) :: {state(), Keyword.t}

  @doc """
  The `handle_event` function is executed each time an event record is
  received on the `Chronik.PubSub` and is responsible of the
  projection state transition.

  The return value is a new `state` for the received `record`
  """
  @callback handle_event(record :: Chronik.EventRecord, state :: state()) :: state()

  use GenServer

  require Logger

  require Chronik.Utils

  alias Chronik.{EventRecord, Config, Utils}

  defstruct [:version,
             :pub_sub,
             :store,
             :projection_state,
             :projection]

  # API

  @doc "Return the current state for `projection_id`"
  def state(projection_id) do
    GenServer.call(projection_id, :state)
  end

  @doc "Start a new `projection`"
  def start_link(projection, opts) when is_atom(projection) do
    GenServer.start_link(__MODULE__, [projection, opts], name: projection)
  end

  # GenServer callbacks

  def init([projection, opts]) do
    {store, pub_sub} = Config.fetch_adapters()

    # Call the client code to get the initial state. If the projection
    # has a snapshot it will return a valid state and in options a
    # version where the snapshot was taken.
    {state, options} = projection.init(opts)

    # By default start reading from the beginning of time.
    version = Keyword.get(options, :version, :empty)

    # By default the consistency of a projection is :eventual.
    consistency = Keyword.get(options, :consistency, :eventual)

    # First subscribe to the PubSub to start receiving records. Note
    # that as the GenServer is synchronous we won't process any
    # messages until we finish the init function.
    :ok = pub_sub.subscribe([consistency: consistency])

    # From the state return by the client code and its version, read
    # from the Store (starting at version) de replay the missing
    # events.
    {state, version} = fetch_and_replay(version, state, projection, store)

    {:ok, %__MODULE__{version: version,
                      pub_sub: pub_sub,
                      store: store,
                      projection_state: state,
                      projection: projection}}
  end

  def handle_call(:state, _from, %__MODULE__{projection_state: ps} = state) do
    {:reply, ps, state}
  end

  # Process an incoming record synchronously. This is called when the
  # subscription to the PubSub is configured as :strict.
  def handle_call({:process, e}, _from, state) do
    # This follows the same path than asynchronous records.
    {:noreply, new_state} = handle_info(e, state)
    {:reply, :ok, new_state}
  end

  # When configured with eventual consistency the records are
  # delivered as messages processed by the handle_info.
  def handle_info(%EventRecord{} = e, %__MODULE__{projection: projection,
                                                  store: store,
                                                  projection_state: ps,
                                                  version: version} = state) do
    new_state =
      # Use the Store to compare the current version and the version
      # of the incoming record.
      case store.compare_version(version, e.version) do
        # If the record that came from the PubSub is the next_one to
        # the one we last saw, transition to the following state.
        :next_one ->
          Utils.debug("#{projection} :applying event coming from the PubSub with version #{e.version}")

          # Update the consumer state applying the record calling the
          # client `handle_event/2` code.
          %{state | version: e.version,
                    projection_state: projection.handle_event(e, ps)}
        :past ->
          # If the version of the event that came from the PubSub is from
          # the past, just ingnore it.
          Utils.debug("#{projection} :discarding event from the past with version #{e.version}")
          state
        :equal ->
          # If we already saw this event skip it.
          state
        :future ->
          # If the event that came from the PubSub is in the future (BTTF)
          # try to fetch the missing events from the Store and the apply
          # the incoming record.
          Utils.debug("#{projection} :event(s) coming from the future with version " <>
                          "#{e.version}. Fetching missing events starting at " <>
                          "version #{version} from the store.")

          # Note that the catch up is a best effort approach since
          # events could still be missing in the Store.
          {proj_state, new_version} =
            catch_up(version, ps, projection, store)

          %{state | version: new_version,
                    projection_state: proj_state}
      end

    {:noreply, new_state}
  end

  # Internal functions
  defp make_stream_handler(projection_state, version, projection) do
    fn stream ->
      Enum.reduce(stream, {projection_state, version},
        fn record, {state, _version} ->
          {projection.handle_event(record, state), record.version}
        end)
    end
  end

  # Try to catch up to a future version coming from the PubSub
  # by streaming missing events from the Store.
  defp catch_up(version, projection_state, projection, store) do
    from = if version == :empty, do: :all, else: version

    stream_handler = make_stream_handler(projection_state, version, projection)

    case store.stream(stream_handler, from) do
      {^projection_state, :empty} ->
        # There were no events on the Store to catch up.
        Utils.warn("#{projection} :no events found on the Store to do a catch_up")
        {projection_state, :empty}
      {new_projection_state, new_version} ->
        # Found some events on the store. Update the projection state.
        Utils.debug("#{projection} :catching up events from the store starting at version #{version}")
        {new_projection_state, new_version}
    end
  end

  # Replay events from the store.
  defp fetch_and_replay(:current, projection_state, _projection, store) do
    {projection_state, store.current_version()}
  end
  defp fetch_and_replay(version, projection_state, projection, store) do
    from = if version == :empty, do: :all, else: version

    stream_handler = make_stream_handler(projection_state, version, projection)

    case store.stream(stream_handler, from) do
      {^projection_state, :empty} ->
        Utils.warn("#{projection} :no events found in the store.")
        {projection_state, :empty}
      {new_projection_state, new_version} ->
        Utils.debug("#{projection} :re-playing events from version #{version}")
        {new_projection_state, new_version}
    end
  end
end
