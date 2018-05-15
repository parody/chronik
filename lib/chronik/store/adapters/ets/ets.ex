defmodule Chronik.Store.Adapters.ETS do
  @moduledoc false

  use GenServer

  alias Chronik.{EventRecord, Utils}

  require Logger

  require Chronik.Utils

  @behaviour Chronik.Store

  @name __MODULE__
  @table Module.concat(__MODULE__, Table)
  @snapshot_table Module.concat(__MODULE__, SnapshotTable)

  # API

  def append(aggregate, events, opts \\ [version: :any]) do
    GenServer.call(@name, {:append, aggregate, events, opts})
  end

  def fetch(version \\ :all) do
    GenServer.call(@name, {:fetch, version})
  end

  def snapshot(aggregate, state, version) do
    GenServer.call(@name, {:snapshot, aggregate, state, version})
  end

  def get_snapshot(aggregate) do
    GenServer.call(@name, {:get_snapshot, aggregate})
  end

  def remove_events(aggregate) do
    GenServer.call(@name, {:remove_events, aggregate})
  end

  def fetch_by_aggregate(aggregate, version \\ :all) do
    GenServer.call(@name, {:fetch_by_aggregate, aggregate, version})
  end

  def compare_version(a, a), do: :equal

  def compare_version(:empty, "0"), do: :next_one

  def compare_version(a, b) when is_bitstring(a) and is_bitstring(b) do
    case {String.to_integer(a), String.to_integer(b)} do
      {v1, v2} when v2 == v1 + 1 -> :next_one
      {v1, v2} when v2 > v1 + 1 -> :future
      {v1, v2} when v2 < v1 -> :past
    end
  end

  def current_version, do: GenServer.call(@name, :current_version)

  def stream_by_aggregate(aggregate, fun, version \\ :all) do
    wrapper_fn = GenServer.call(@name, {:stream_by_aggregate, aggregate, version})
    wrapper_fn.(fun)
  end

  def stream(fun, version \\ :all) do
    wrapper_fn = GenServer.call(@name, {:stream, version})
    wrapper_fn.(fun)
  end

  # GenServer callbacks

  def child_spec(_store, opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, opts},
      type: :worker,
      restart: :permanent
    }
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def init([]) do
    # We use two tables. The @table to store the domain events
    # and @snapshot_table to store the snapshots.
    :ets.new(@table, [:named_table, :private])
    :ets.new(@snapshot_table, [:named_table, :private])
    {:ok, nil}
  rescue
    _ -> {:stop, {:error, "event store already started"}}
  end

  def handle_call({:remove_events, aggregate}, _from, state) do
    events =
      current_records()
      |> Enum.drop_while(&(&1.aggregate == aggregate))

    true = :ets.insert(@table, {:records, events})

    {:reply, :ok, state}
  end

  def handle_call(:current_version, _from, state) do
    {:reply, current_version_local(), state}
  end

  def handle_call({:append, aggregate, events, opts}, _from, state) do
    aggregate_version = get_aggregate_version(aggregate)
    version = Keyword.get(opts, :version)
    Utils.debug("appending records #{inspect(events)} from the aggregate #{inspect(aggregate)}")

    # Check that the version asked by the client is consistent with the Store.
    if (version == :no_stream and aggregate_version == :empty) or version == :any or
         (is_bitstring(version) and version == aggregate_version) do
      {:reply, do_append(events, aggregate, aggregate_version), state}
    else
      {:reply, {:error, "wrong expected version"}, state}
    end
  end

  # Fetch callback returns all the records from the all-stream starting at
  # a given version.
  def handle_call({:fetch, version}, _from, state) do
    drop =
      case version do
        :all -> 0
        version -> String.to_integer(version) + 1
      end

    fetch_version =
      case current_records() do
        [] ->
          :empty

        records ->
          records
          |> List.last()
          |> Map.get(:version)
      end

    records = Enum.drop(current_records(), drop)
    Utils.debug("fetched records from #{inspect(version)}: #{inspect(records)}.")
    {:reply, {:ok, fetch_version, records}, state}
  end

  # Returns the records for a given aggregate starting at version.
  def handle_call({:fetch_by_aggregate, aggregate, version}, _from, state) do
    filter = fn records ->
      case version do
        :all ->
          records

        _ ->
          records
          |> Enum.drop_while(&(&1.aggregate_version != version))
          |> Enum.drop(1)
      end
    end

    records =
      current_records()
      |> Enum.filter(&(&1.aggregate == aggregate))
      |> filter.()

    Utils.debug("fetched records for aggregate #{inspect(aggregate)}: #{inspect(records)}.")
    {:reply, {:ok, get_aggregate_version(aggregate), records}, state}
  end

  def handle_call({:stream, version}, _from, state) do
    drop =
      case version do
        :all -> 0
        version -> String.to_integer(version) + 1
      end

    records = Enum.drop(current_records(), drop)
    Utils.debug("fetched records from #{inspect(version)}: #{inspect(records)}.")

    ret = fn fun ->
      records
      |> Stream.take_while(fn _ -> true end)
      |> fun.()
    end

    {:reply, ret, state}
  end

  def handle_call({:stream_by_aggregate, aggregate, version}, _from, state) do
    filter = fn records ->
      case version do
        :all ->
          records

        _ ->
          records
          |> Enum.drop_while(&(&1.aggregate_version != version))
          |> Enum.drop(1)
      end
    end

    records =
      current_records()
      |> Enum.filter(&(&1.aggregate == aggregate))
      |> filter.()

    Utils.debug("fetched records for aggregate #{inspect(aggregate)}: #{inspect(records)}.")

    ret = fn fun ->
      records
      |> Stream.take_while(fn _ -> true end)
      |> fun.()
    end

    {:reply, ret, state}
  end

  # Take a snapshot of the aggregate state and store in the Store.
  def handle_call({:snapshot, aggregate, aggregate_state, version}, _from, state) do
    true = :ets.insert(@snapshot_table, {aggregate, {version, aggregate_state}})
    Utils.debug("doing a snapshot for aggregate #{inspect(aggregate)}")
    {:reply, :ok, state}
  end

  # Retrieve a snapshot (if any) from the Store.
  def handle_call({:get_snapshot, aggregate}, _from, state) do
    case :ets.lookup(@snapshot_table, aggregate) do
      [] ->
        Utils.debug("no snapshot found on the store.")
        {:reply, nil, state}

      [{^aggregate, snapshot}] ->
        Utils.debug("found a snapshot found on the store.")
        {:reply, snapshot, state}
    end
  end

  # Internal functions

  defp current_records do
    case :ets.lookup(@table, :records) do
      [] -> []
      [{:records, records}] -> records
    end
  end

  defp do_append(events, aggregate, aggregate_version) do
    {new_records, new_version, aggregate_version} =
      Enum.reduce(events, {[], current_version_local(), aggregate_version}, fn event,
                                                                               {records, version,
                                                                                aggregate_version} ->
        next_agg_version = next_version(aggregate_version)
        next_version = next_version(version)
        record = EventRecord.create(event, aggregate, next_version, next_agg_version)

        {
          records ++ [record],
          next_version,
          next_agg_version
        }
      end)

    Utils.debug("appending records: #{inspect(new_records)}")

    true = :ets.insert(@table, {:version, new_version})
    true = :ets.insert(@table, {:records, current_records() ++ new_records})
    :ets.lookup(@table, :records)

    {:ok, aggregate_version, new_records}
  end

  defp get_aggregate_version(aggregate) do
    num_records =
      current_records()
      |> Enum.filter(&(&1.aggregate == aggregate))
      |> length()

    case num_records do
      0 -> :empty
      v -> "#{v - 1}"
    end
  end

  defp next_version(version) do
    case version do
      :empty -> "0"
      v -> "#{String.to_integer(v) + 1}"
    end
  end

  defp current_version_local do
    case :ets.lookup(@table, :version) do
      [] -> :empty
      [{:version, version}] -> version
    end
  end
end
