defmodule Chronik.Aggregate do
  @moduledoc """
  Chronik aggregate
  """

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Chronik.Aggregate

      use GenServer

      import Chronik.EventMonad

      alias Chronik.{Store, PubSub}

      @registry Chronik.AggregateRegistry

      {store, pubsub} = Chronik.Config.fetch_adapters()

      @store store
      @pubsub pubsub

      # API

      def execute(state, fun) do
        events = state |> fun.() |> List.wrap()
        new_state = Enum.reduce(events, state, &next_state(&2, &1))
        {new_state, events}
      end

      def fail(message) do
        {:error, message}
      end

      def call(aggregate_id, function) do
        case Registry.lookup(@registry, aggregate_id) do
          [] ->
            case Chronik.Aggregate.Supervisor.start_aggregate(__MODULE__, aggregate_id) do
              {:ok, pid} ->
                GenServer.call(pid, function)
              {:error, reason} ->
                raise "cannot create process for aggregate root #{aggregate_id}: #{inspect reason}"
            end
          [{pid, _metadata}] ->
            GenServer.call(pid, function)
        end
      end

      def get(aggregate_id) do
        GenServer.call(via(aggregate_id), :get)
      end

      def start_link(id) do
        GenServer.start_link(__MODULE__, {__MODULE__, id}, name: via({__MODULE__, id}))
      end

      # GenServer callbacks

      def init({aggregate, id}) do
        {:ok, {aggregate, maybe_load_from_store(aggregate, id)}}
      end

      def handle_call(:get, _from, state) do
        {:reply, state, state}
      end
      def handle_call(fun, _from, {aggregate, state} = s) when is_function(fun, 1) do
        try do
          case fun.(state) do
            {nil, _} ->
              {:stop, :normal, {aggregate, nil}}
            {_state, {:error, _message} = error} ->
              {:reply, error, s}
            {new_state, notifications} ->
              aggregate_id = get_aggregate_id(new_state)
              {:ok, new_offset, records} = @store.append(aggregate_id, notifications, version: :any)
              @pubsub.broadcast({aggregate, aggregate_id}, records)
              {:reply, {:ok, new_offset, records}, {aggregate, new_state}}
          end
        rescue
          e -> {:reply, {:error, e}, s}
        end
      end

      # Internal functions

      defp via({aggregate, id}) do
        {:via, Registry, {Chronik.AggregateRegistry, {aggregate, id}}}
      end

      # Loads the aggregate state from the domain event store.
      # It returns the state on success or nil if there is no recorded domain
      # events for the aggregate.
      defp maybe_load_from_store(_aggregate, id) do
        case @store.fetch(id) do
          {:error, "stream not found"} ->
            nil
          events ->
            Enum.reduce(events, nil, &(next_state(&2, &1.data)))
        end
      end
    end
  end

  def start_link(aggregate, id) do
    aggregate.start_link(id)
  end

  # Callbacks

  @callback get_aggregate_id(Chronik.state) :: term()
  @callback handle_command(Chronik.command) :: :ok | {:error, term()}
  @callback next_state(Chronik.state, Chronik.event) :: Chronik.state
end
