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

      # API

      def execute(state, fun) do
        events = fun.(state) |> List.wrap()
        new_state = Enum.reduce(events, state, &next_state(&2, &1))
        {new_state, events}
      end

      def fail(message) do
        {:error, message}
      end

      def call(aggregate_id, function) do
        case Registry.lookup(@registry, aggregate_id) do
          [] ->
            case Chronik.Aggregate.Supervisor.start_aggregate(aggregate_id) do
              {:ok, pid} ->
                GenServer.call(pid, function)
              {:error, _} ->
                raise "cannot create process for aggregate root #{aggregate_id}"
            end
          [{pid, _metadata}] ->
            GenServer.call(pid, function)
        end
      end

      def get(aggregate_id) do
        GenServer.call(via(aggregate_id), :get)
      end

      def start_link(aggregate_id) do
        GenServer.start_link(__MODULE__, aggregate_id, name: via(aggregate_id))
      end

      # GenServer callbacks

      def init(aggregate_id) do
        {:ok, maybe_load_from_store(aggregate_id)}
      end

      def handle_call(:get, _from, state) do
        {:reply, state, state}
      end
      def handle_call(fun, _from, state) when is_function(fun, 1) do
        try do
          case fun.(state) do
            {nil, _} ->
              {:stop, :normal, nil}
            {_state, {:error, _message} = error} ->
              {:reply, error, state}
            {new_state, notifications} ->
              aggregate_id = get_aggregate_id(new_state)
              Store.append(aggregate_id, notifications, version: :any)
              PubSub.broadcast(aggregate_id, notifications)
              {:reply, :ok, new_state}
          end
        rescue
          e -> {:reply, {:error, e}, state}
        end
      end

      # Internal functions

      defp via(aggregate_id) do
        {:via, Registry, {Chronik.AggregateRegistry, aggregate_id}}
      end

      # Loads the aggregate state from the domain event store.
      # It returns the state on success or nil if there is no recorded domain
      # events for the aggregate.
      defp maybe_load_from_store(aggregate_id) do
        case Store.fetch(aggregate_id) do
          {:error, "stream not found"} ->
            nil
          events ->
            Enum.reduce(events, nil, &(next_state(&2, &1.data)))
        end
      end
    end
  end

  @callback get_aggregate_id(Chronik.state) :: term()
  @callback handle_command(Chronik.command) :: :ok | {:error, term()}
  @callback next_state(Chronik.state, Chronik.event) :: Chronik.state
end
