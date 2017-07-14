defmodule Chronik.Projection do
  @moduledoc """
  Chronik projection
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Chronik.Projection

      {store, pubsub} = Chronik.Config.fetch_adapters()

      @projection __MODULE__
      @worker     Module.concat([__MODULE__, Worker])
      @consumer   Module.concat([__MODULE__, Consumer])

      @store store
      @pubsub pubsub

      unquote(projection())
      unquote(consumer())
      unquote(supervisor())

      @doc "Return the current projection state"
      def state, do: @worker.state
    end
  end

  defp supervisor do
    quote do
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
        consumer_args = [@store, @pubsub, @worker, opts]
        worker_args = [@projection]
        children = [{@worker, worker_args},
                    {@consumer, consumer_args}]
        Chronik.Projection.Supervisor.start_link(__MODULE__, children)
      end
    end
  end

  defp projection do
    quote do
      defmodule @worker do
        @moduledoc false

        use GenServer

        # API

        def state do
          GenServer.call(__MODULE__, :state)
        end

        def start_link(opts) do
          GenServer.start_link(__MODULE__, opts, name: __MODULE__)
        end

        # GenServer callbacks

        def init([projection]) do
          {:ok, {projection, projection.init()}}
        end

        def handle_call(:state, _from, {_, state} = s) do
          {:reply, state, s}
        end

        def handle_cast({:next_state, event}, {projection, state}) do
          {:noreply, {projection, projection.next_state(state, event)}}
        end
      end
    end
  end

  defp consumer do
    quote do
      defmodule @consumer do
        use GenServer

        require Logger

        alias Chronik.EventRecord

        # API

        @doc "Fetch and reply events to `projection`"
        @spec fetch_and_reply(streams :: [Chronik.stream], atom, pid) :: Map.t
        def fetch_and_reply(streams, store, projection) do
          Enum.reduce(streams, %{}, fn {aggregate, stream, offset}, acc ->
            with {:ok, new_offset, records} <- store.fetch({aggregate, stream}, offset) do
              for %EventRecord{data: event} <- records, do: GenServer.cast(projection, {:next_state, event})
              Map.put(acc, {aggregate, stream}, new_offset)
            else
              {:error, reason} ->
                Logger.warn fn ->
                  ["[#{inspect __MODULE__}<#{inspect {aggregate, stream}}>] ",
                   "no events found in the store. ",
                   "Returning offset=:empty"]
                end
                Map.put(acc, {aggregate, stream}, :empty)
            end
          end)
        end

        @doc false
        def start_link(args) do
          GenServer.start_link(__MODULE__, args, name: __MODULE__)
        end

        # GenServer callbacks

        def init([store, pubsub, worker, streams]) do
          for {aggregate, stream, offset} <- streams do
            :ok = pubsub.subscribe({aggregate, stream})
          end

          projection = Process.whereis(worker)

          {:ok, %{cursors: fetch_and_reply(streams, store, projection),
                  projection: projection,
                  store: store, pubsub: pubsub}}
        end

        def handle_info(%EventRecord{stream: stream, offset: offset} = e,
                        %{store: store, projection: projection} = state) do
          consumer_offset = Map.get(state.cursors, stream, :empty)
          new_state =
            cond do
              (consumer_offset == :empty and offset == 0) or
              offset == consumer_offset + 1 ->
                Logger.debug ["[#{inspect __MODULE__}<#{inspect stream}>] ",
                 "applying event coming from the bus  with offset #{offset}"]
                :ok = GenServer.cast(state.projection, {:next_state, e.data})
                %{state | cursors: Map.put(state.cursors, stream, offset)}

              offset <= consumer_offset ->
                Logger.debug ["[#{inspect __MODULE__}<#{inspect stream}>] ",
                   "discarding event from the past with offset #{offset}. consumer_offset #{consumer_offset}"]
                state

              offset > consumer_offset + 1 ->
                Logger.debug ["[#{inspect __MODULE__}<#{inspect stream}>] ",
                 "event(s) coming from the future with offset #{offset}. ",
                 "Fetching missing events starting at offset #{consumer_offset} from the store."]
                {:ok, new_offset, records} = store.fetch(stream, consumer_offset)
                for %EventRecord{data: event} <- records,
                   do: :ok = GenServer.cast(projection, {:next_state, event})
                Logger.debug ["[#{inspect __MODULE__}<#{inspect stream}>] ",
                 "best effort reading up to offset #{new_offset}"]
                %{state | cursors: Map.put(state.cursors, stream, new_offset)}
            end

          {:noreply, new_state}
        end
      end
    end
  end

  @typedoc "The `projection_state` represents the state of an projection."
  @type projection_state :: term()

  # Callbacks
  @doc """
  The `init` function defines the intial state of an aggregate. 
  """
  @callback init() :: projection_state

  @doc """
  The `next_state` function is executed each time an event is received
  on the bus and is responsible of the projeciton state transition.

  The return value is a new `state` for the received `event`
  """
  @callback next_state(state :: projection_state, event :: Chronik.event) :: projection_state
end
