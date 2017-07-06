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
        children = [{Module.concat([__MODULE__, Worker]), worker_args},
                    {Module.concat([__MODULE__, Consumer]), consumer_args}]
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
          Enum.reduce(streams, %{}, fn {aggregate, stream, _, offset}, acc ->
            with {:ok, new_offset, events} <- store.fetch(stream, offset) do
              for event <- events, do: GenServer.cast(projection, {:next_state, event})
              Map.put(acc, stream, new_offset)
            else
              {:error, reason} ->
                Logger.warn fn ->
                  ["[#{inspect __MODULE__}<#{inspect stream}>] ",
                   "starting from offset 0: #{inspect reason}"]
                end
                Map.put(acc, stream, 0)
            end
          end)
        end

        @doc false
        def start_link(args) do
          GenServer.start_link(__MODULE__, args, name: __MODULE__)
        end

        # GenServer callbacks

        def init([store, pubsub, worker, streams]) do
          _ = Enum.map(streams, fn {aggregate, stream, predicate, offset} ->
            :ok = pubsub.subscribe({aggregate, stream}, predicate)
          end)

          projection = Process.whereis(worker)

          {:ok, %{cursors: fetch_and_reply(streams, store, projection),
                  projection: projection,
                  store: store, pubsub: pubsub}}
        end

        def handle_info(%EventRecord{stream: stream, offset: offset} = e,
                        %{store: store, projection: projection} = state) do
          consumer_offset = Map.get(state.cursors, stream)
          new_state =
            cond do
              offset == consumer_offset ->
                GenServer.cast(state.projection, {:next_state, e.data})
                %{state | cursors: Map.put(state.cursors, stream, offset + 1)}

              offset <= consumer_offset ->
                state

              offset > consumer_offset ->
                {:ok, new_offset, events} = store.fetch(stream, offset)
                for event <- events, do: GenServer.cast(projection, {:next_state, event})
                %{state | cursors: Map.put(state.cursors, stream, new_offset)}
            end

          {:noreply, new_state}
        end
      end
    end
  end

  # Callbacks

  @callback init() :: Chronik.state
  @callback next_state(Chronik.state, Chronik.event) :: Chronik.state
end
