defmodule Chronik.Aggregate.Core do
  use GenServer
  alias Chronik.Aggregate.Supervisor
  require Logger

  # Fetch the configuration for the Store and the PubSub.
  {store, pub_sub} = Chronik.Config.fetch_adapters()

  # Set the modules attributes
  @registry Chronik.AggregateRegistry
  @store store
  @pub_sub pub_sub

  ##
  ## Aggregate API
  ##

  def call(module, id, function) do
    case Registry.lookup(@registry, {module, id}) do
      [] ->
        case Supervisor.start_aggregate(module, id) do
          {:ok, pid} ->
            GenServer.call(pid, {module, function})
          {:error, reason} ->
            {:error, "cannot create process for aggregate root " <>
                     "{#{module}, #{id}}: #{inspect reason}"}
        end
      [{pid, _metadata}] -> GenServer.call(pid, {module, function})
    end
  end

  @doc """
  The `execute` function is used to wrap the state and events in the
  `handle_command`.
  """
  def execute(module, {state, events}, fun) do
    new_events = List.wrap(fun.(state))
    {apply_events(new_events, state, module), events ++ new_events}
  end

  @doc """
  The `get(module, id)` function returns the currente aggregate state. This should
  only be used for debugging purposes.
  """
  @spec get(module(), Chronik.id) :: Chronik.Aggregate.state
  def get(module, id), do: GenServer.call(via(module, id), :get)

  ##
  ## GenServer API
  ##

  def start_link(module, id) do
    GenServer.start_link(__MODULE__, {module, id}, name: via(module, id))
  end

  @doc false
  def init({module, id}) do
    log(id, "starting aggregate.")
    {:ok, {id, load_from_store(module, id), update_timer(nil, get_shutdown_timeout(module)),
      {0, 0}}}
  end

  ##
  ## GenServer Callbacks
  ##

  # The :get returns the current aggregate state.
  @doc false
  def handle_call(:get, _from, {id, state, timer, counters}) do
    {:reply, state, {id, state, timer, counters}}
  end
  # When called with a function, the aggregate executes the function in
  # the current state and if no exceptions were raised, it stores and
  # publishes the events to the PubSub.
  def handle_call({module, fun}, _from, {_id, state, _timer, _counters} = s)
    when is_function(fun, 1) do

    try do
      {state, []}
      |> fun.()
      |> store_and_publish(s, module)
    rescue
      e ->
        if state do
          {:reply, {:error, e}, s}
        else
          {:stop, :normal, {:error, e}, s}
        end
    end
  end

  @doc false
  # The shutdown timeout is implemented by auto-sending a message :shutdown
  # to the current process.
  def handle_info(:shutdown, {id, _state, _timer, _counters} = s) do
    # TODO: Do a snapshot before going down.
    log(id, "aggregate going down gracefully due to inactivity.")
    {:stop, :normal, s}
  end

  ##
  ## Internal functions
  ##
  defp via(module, id) do
    {:via, Registry, {@registry, {module, id}}}
  end

  # Loads the aggregate state from the domain event store.
  # It returns the state on success or nil if there is no recorded domain
  # events for the aggregate.
  defp load_from_store(module, id) do
    aggregate_tuple = {module, id}
    {version, state} =
      case @store.get_snapshot(aggregate_tuple) do
        nil ->
          log(id, "no snapshot found on the store.")
          {:all, nil}
        {version, _state} = snapshot ->
          log(id, "found a snapshot on the store with version " <>
                  "#{inspect version}")
          snapshot
      end
    case @store.fetch_by_aggregate(aggregate_tuple, version) do
      {:error, _} -> state
      {:ok, _version, records} ->
        log(id, "replaynig events from #{inspect version} and on.")
        records
        |> Enum.map(&Map.get(&1, :domain_event))
        |> apply_events(state, module)
    end
  end

  defp apply_events(events, state, module) do
    Enum.reduce(events, state, &module.next_state(&2, &1))
  end

  defp store_and_publish({new_state, events},
    {id, _state, timer, {num_events, blocks}}, module) do

    log(id, "writing events to the store: #{inspect events}")
    {:ok, version, records} = @store.append({module, id}, events)

    log(id, "broadcasting records: #{inspect records}")
    @pub_sub.broadcast(records)

    num_events = num_events + length(events)
    blocks =
      if div(num_events, get_snapshot_every(module)) > blocks do
        log(id, "saving a snapshot with version #{inspect version}")
        @store.snapshot({module, id}, new_state, version)
        div(num_events, get_snapshot_every(module))
      else
        blocks
      end

    {:reply, :ok, {id, new_state, update_timer(timer, get_shutdown_timeout(module)),
      {num_events, blocks}}}
  end

  defp log(id, msg) do
    Logger.debug(fn -> "[#{inspect __MODULE__}:#{inspect id}] #{msg}" end)
  end

  defp update_timer(timer, shutdown_timeout) do
    if timer,
      do: Process.cancel_timer(timer)
    if shutdown_timeout != :infinity,
      do: Process.send_after(self(), :shutdown, shutdown_timeout)
  end

  defp get_shutdown_timeout(module), do:
    Chronik.Config.get_config(module, :shutdown_timeout, :infinity)

  defp get_snapshot_every(module), do:
    Chronik.Config.get_config(module, :snapshot_every, 1000)
end