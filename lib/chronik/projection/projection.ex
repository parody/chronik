defmodule Chronik.Projection do
  @moduledoc """
  The Projection is a read model connected to the PubSub.

  Client code has to implement the
  `Chronik.Projection.init` function and the
  state transition `Chronik.Projection.next_state`.

  Example:
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
    use Chronik.Projection

    alias DomainEvents.CounterCreated
    alias DomainEvents.CounterIncremented

    def init(_opts), do: {nil, []}

    def next_state(nil, %CounterCreated{}) do
      0
    end
    def next_state(value, %CounterIncremented{increment: increment}) do
      value + increment
    end
  end
  ```
  """

  @typedoc "The `state` represents the state of an projection."
  @type state :: term()

  # Callbacks
  @doc """
  The `init` function defines the
  intial state of an projection and some options.

  The accepted `options`:
  * `version` start replaying events from `version` and up. A `:all`  value
    indicates that the replay should be from the begining of times.
  * `consistency` indicates how the projection should subscribe to the
  PubSub. Possible values are `:eventual` (defualt) and `strict`.
  """
  @callback init(opts :: Keyword.t) :: {state, Keyword.t}

  @doc """
  The `next_state` function is executed each time an event record is received
  on the PubSub and is responsible of the projeciton state transition.

  The return value is a new `state` for the received `record`
  """
  @callback next_state(state :: state, record :: Chronik.EventRecord) :: state
  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Chronik.Projection

      {store, pub_sub} = Chronik.Config.fetch_adapters()

      @projection __MODULE__
      @consumer   Module.concat([__MODULE__, Consumer])

      @store store
      @pub_sub pub_sub

      @doc """
      Returns the current projection state. This should only be used
      for debuggin purposes.
      """
      @spec state() :: Chronik.Projection.state
      def state do
        GenServer.call(@consumer, :state)
      end

      @doc false
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      defoverridable child_spec: 1

      @doc false
      def start_link(opts) do
        args = [@store, @pub_sub, @projection, opts]
        child = [{@consumer, args}]
        Chronik.Projection.Supervisor.start_link(__MODULE__, child)
      end

      defmodule @consumer do
        @moduledoc false

        use GenServer

        require Logger

        alias Chronik.EventRecord

        ##
        ## GenServer callbacks
        ##
        def start_link(opts) do
          GenServer.start_link(__MODULE__, opts, name: __MODULE__)
        end

        def init([store, pub_sub, projection, opts]) do
          # Call the client code to get the initial state.
          # If the projection has a snapshot it will return a valid state
          # and in options a version where the snapshot was taken.
          {state, options} = projection.init(opts)
          # By default start reading from the beginning of time.
          version = Keyword.get(options, :version, :all)
          # By defualt the consistency of a projection is :eventual.
          consistency = Keyword.get(options, :consistency, :eventual)
          # First subscribe to the PubSub to start receiving records.
          # Note that as the GenServer is synchronous we won't process
          # any messages until we finish the init function.
          :ok = pub_sub.subscribe([consistency: consistency])
          # From the state return by the client code and its version, read
          # from the Store (starting at version) de replay the missing events.
          {version, state} = fetch_and_replay(version, state, store, projection)
          {:ok, %{version: version,
                  projection_state: state,
                  projection: projection,
                  store: store,
                  pub_sub: pub_sub}}
        end

        # Return the current projection state.
        def handle_call(:state, _from, %{projection_state: ps} = state) do
          {:reply, ps, state}
        end
        # Process an incoming record synchronously. This is called when the
        # subscription to the PubSub is configured as :strict.
        def handle_call({:process, e}, _from, state) do
          # This follows the same path than asynchronous records.
          {:noreply, new_state} = handle_info(e, state)
          {:reply, :ok, new_state}
        end

        # When configured with eventual consistency the records are delivered
        # as messages processed by the handle_info.
        def handle_info(%EventRecord{} = e,
                        %{store: store, projection: projection,
                          pub_sub: pub_sub, version: version} = state) do
          new_state =
            # Use the Store to comapre the current version and the version
            # of the incoming record.
            case store.compare_version(version, e.version) do
              # If the record that came from the PubSub is the next_one to
              # the one we last saw, transition to the following state.
              :next_one ->
                log("applying event coming from the PubSub with version " <>
                    " #{e.version}")
                # Update the Consumer state aplying the record calling the
                # client next_state code.
                %{state |
                  version: e.version,
                  projection_state:
                  apply_records(state.projection_state, [e], projection)}
              :past ->
                # If the version of the event that came from the PubSub is from
                # the past, just ingnore it.
                log("discarding event from the past with version #{e.version}")
                state
              :equal ->
                # If we already saw this event skip it.
                state
              :future ->
                # If the event that came from the PubSub is in the future (BTTF)
                # try to fetch the missing events from the Store and the apply
                # the incoming record.
                log("event(s) coming from the future with version " <>
                    "#{e.version}. Fetching missing events starting at " <>
                    "version #{version} from the store.")

                # Note that the catch up is a best effort approach since
                # events could still be missing in the Store.
                {new_version, proj_state} =
                  catch_up(version, state.projection_state, state.store,
                    state.projection)

                %{state |
                  version: new_version,
                  projection_state: proj_state}
            end
          {:noreply, new_state}
        end

        ##
        ## Internal functions
        ##
        defp apply_records(state, records, projection) do
          Enum.reduce(records, state, &projection.next_state(&2, &1))
        end

        # Try to catch up to a future version coming from the PubSub
        # by fetching missing events from the Store.
        defp catch_up(version, state, store, projection) do
          case store.fetch(version) do
            {:ok, :empty, []} ->
              # There were no events on the Store to catch up.
              warn("no events found on the Store to do a catch_up")
              {version, state}

            {:ok, new_version, records} ->
                # Found some events on the store. Update the projection state.
                log("catching up events from the store starting at " <>
                    "version #{version}")
                {new_version, apply_records(state, records, projection)}
          end
        end

        # Replay events from the store.
        defp fetch_and_replay(version, state, store, projection) do
          case store.fetch(version) do
            {:ok, :empty, []} ->
              warn("no events found in the store.")
              {:all, state}
            {:ok, new_version, records} ->
                log("re-playing events from version #{version}")
                {new_version, apply_records(state, records, projection)}
          end
        end

        defp log(msg) do
          Logger.debug(fn -> "[#{inspect __MODULE__}] #{msg}" end)
        end

        defp warn(msg) do
          Logger.warn(fn -> "[#{inspect __MODULE__}] #{msg}" end)
        end
      end
    end
  end
end
