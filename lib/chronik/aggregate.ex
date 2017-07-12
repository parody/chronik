defmodule Chronik.Aggregate do
  @moduledoc """
  Chronik aggregate
  """

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Chronik.Aggregate

      use GenServer

      alias Chronik.{Store, PubSub}

      @registry Chronik.AggregateRegistry

      {store, pubsub} = Chronik.Config.fetch_adapters()

      @store store
      @pubsub pubsub

      # API

      defp apply_events(events, state) do
        Enum.reduce(events, state, &next_state(&2, &1))
      end

      def execute({state, events}, fun) do
        new_events = List.wrap(fun.(state))
        {apply_events(new_events, state), events ++ new_events}
      end

      def call(aggregate_id, function) do
        case Registry.lookup(@registry, {__MODULE__, aggregate_id}) do
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

      def get_aggregate_id(%__MODULE__{id: id}) do
        id
      end

      def get(aggregate_id) do
        GenServer.call(via({__MODULE__, aggregate_id}), :get)
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
          {new_state, events} = fun.({state, []})
          aggregate_id = get_aggregate_id(new_state)
          if state != nil and aggregate_id != get_aggregate_id(state) do
            raise "The next_state function can not change the aggregate_id"
          end
          {:ok, new_offset, records} =
            @store.append({aggregate, aggregate_id}, events, version: :any)
          @pubsub.broadcast({aggregate, aggregate_id}, records)
          {:reply, {:ok, new_offset}, {aggregate, new_state}}
        rescue
          e ->
            case state do
              nil -> {:stop, :normal, e, s}
              _state -> {:reply, {:error, e}, s}
            end
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
          {:error, _} -> nil
          events -> apply_events(events, nil)
        end
      end
    end
  end

  def start_link(aggregate, id) do
    aggregate.start_link(id)
  end

  # Callbacks

  @callback handle_command(Chronik.command) :: {:ok | non_neg_integer()}
                                             | {:error, term()}
  @callback next_state(Chronik.state, Chronik.event) :: Chronik.state
end
