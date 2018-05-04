defmodule Chronik.Store.Adapters.Ecto do
  @moduledoc """
  Ecto adapter for `Chronik.Store`

  ## Configuration

  You can configure compression for the aggregate snapshot and domain
  events only for this adapter. By default both values are at 0
  (compression disabled).

  - `:aggregate_compression_level`
  - `:domain_event_compression_level`

  Both accept an integer from 0 to 9, being 9 the highest compression.
  """

  @behaviour Chronik.Store

  use GenServer

  import Ecto.Query

  alias Ecto.DateTime
  alias Chronik.Store.Adapters.Ecto.ChronikRepo, as: Repo
  alias Chronik.Store.Adapters.Ecto.{Aggregate, DomainEvents}
  alias Chronik.EventRecord

  require Logger

  @name __MODULE__
  @epoch :calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})

  @aggregate_compression Application.get_env(:chronik, __MODULE__)[:aggregate_compression_level] || 0
  @domain_event_compression Application.get_env(:chronik, __MODULE__)[:domain_event_compression_level] || 0

  # API

  def append(aggregate, events, opts \\ [version: :any]) do
    GenServer.call(__MODULE__, {:append, aggregate, events, opts})
  end

  def snapshot(aggregate, state, version) do
    GenServer.call(__MODULE__, {:snapshot, aggregate, state, version})
  end

  def get_snapshot(aggregate) do
    GenServer.call(__MODULE__, {:get_snapshot, aggregate})
  end

  def fetch_by_aggregate(aggregate, version \\ :all) do
    GenServer.call(@name, {:fetch_by_aggregate, aggregate, version})
  end

  def fetch(version \\ :all) do
    GenServer.call(@name, {:fetch, version})
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

  def compare_version(a, :empty) when is_number(a), do: :past

  def compare_version(_, _), do: :error

  def current_version(), do: GenServer.call(@name, :current_version)

  def stream_by_aggregate(aggregate, fun, version \\ :all) do
    transaction = GenServer.call(@name, {:stream_by_aggregate, aggregate, version})
    {:ok, result} = transaction.(fun)
    result
  end

  def stream(fun, version \\ :all) do
    transaction = GenServer.call(@name, {:stream, version})
    {:ok, result} = transaction.(fun)
    result
  end

  def child_spec(_store, opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, opts},
      type: :worker,
      restart: :permanent
    }
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  # GenServer callbacks

  def init(opts) do
    Repo.start_link(opts)
  end

  def handle_call(:current_version, _from, state) do
    {:reply, store_version(), state}
  end

  # Write the events to the DB.
  def handle_call({:append, aggregate, events, opts}, _from, state) do
    aggregate_version = aggregate_version(aggregate)
    version = Keyword.get(opts, :version)

    if (version == :no_stream and aggregate_version == :empty) or version == :any or
         (is_bitstring(version) and version == aggregate_version) do
      {:reply, do_append(aggregate, events), state}
    else
      {:reply, {:error, "wrong expected version"}, state}
    end
  end

  # Get the events for a given aggregate starting at version.
  def handle_call(
        {:fetch_by_aggregate, {aggregate_module, aggregate_id} = aggregate, version},
        _from,
        state
      ) do
    starting_at =
      case version do
        :all -> -1
        v -> String.to_integer(v)
      end

    query =
      from(
        e in DomainEvents,
        join: a in Aggregate,
        where: a.id == e.aggregate_id,
        where: a.aggregate == ^aggregate_module,
        where: a.aggregate_id == ^aggregate_id,
        where: e.aggregate_version > ^starting_at,
        order_by: e.aggregate_version,
        select: %{
          version: e.version,
          aggregate: {a.aggregate, a.aggregate_id},
          domain_event: e.domain_event,
          aggregate_version: e.aggregate_version,
          created: e.created
        }
      )

    case Repo.all(query) do
      [] ->
        {:reply, {:ok, aggregate_version(aggregate), []}, state}

      rows ->
        records = Enum.map(rows, &build_record/1)

        version =
          records
          |> List.last()
          |> Map.get(:aggregate_version)

        {:reply, {:ok, version, records}, state}
    end
  end

  # Fetch all the events from the all-stream starting at version.
  def handle_call({:fetch, version}, _from, state) do
    starting_at =
      case version do
        :all -> -1
        v -> String.to_integer(v)
      end

    query =
      from(
        e in DomainEvents,
        join: a in Aggregate,
        where: a.id == e.aggregate_id,
        where: e.version > ^starting_at,
        order_by: e.version,
        select: %{
          version: e.version,
          aggregate: {a.aggregate, a.aggregate_id},
          domain_event: e.domain_event,
          aggregate_version: e.aggregate_version,
          created: e.created
        }
      )

    case Repo.all(query) do
      [] ->
        {:reply, {:ok, store_version(), []}, state}

      rows ->
        records = Enum.map(rows, &build_record/1)

        version =
          records
          |> List.last()
          |> Map.get(:version)

        {:reply, {:ok, version, records}, state}
    end
  end

  # Take a snapshot and write it to the DB.
  def handle_call({:snapshot, {aggregate, id}, aggregate_state, version}, _from, state) do
    Aggregate
    |> where(aggregate: ^aggregate)
    |> where(aggregate_id: ^id)
    |> Repo.update_all(
      set: [snapshot_version: version,
            snapshot: :erlang.term_to_binary(aggregate_state, compressed: @aggregate_compression)])

    {:reply, :ok, state}
  end

  def handle_call({:get_snapshot, {aggregate, id}}, _from, state) do
    query =
      from(
        a in Aggregate,
        where: a.aggregate == ^aggregate,
        where: a.aggregate_id == ^id,
        where: not is_nil(a.snapshot_version)
      )

    case Repo.one(query) do
      nil ->
        {:reply, nil, state}

      %Aggregate{snapshot_version: version, snapshot: snapshot} ->
        try do
          {:reply, {"#{version}", :erlang.binary_to_term(snapshot)}, state}
        rescue
          _ ->
            Logger.error(
              "could not load the snapshot for " <>
                "#{inspect({aggregate, id})} from the " <> "store. Possible data corruption."
            )

            {:reply, nil, state}
        end
    end
  end

  def handle_call({:stream, version}, _from, state) do
    starting_at =
      case version do
        :all -> -1
        v -> String.to_integer(v)
      end

    query =
      from(
        e in DomainEvents,
        join: a in Aggregate,
        where: a.id == e.aggregate_id,
        where: e.version > ^starting_at,
        order_by: e.version,
        select: %{
          version: e.version,
          aggregate: {a.aggregate, a.aggregate_id},
          domain_event: e.domain_event,
          aggregate_version: e.aggregate_version,
          created: e.created
        }
      )

    ret = fn fun ->
      Repo.transaction(fn ->
        query
        |> Repo.stream()
        |> Stream.map(&build_record/1)
        |> fun.()
      end)
    end

    {:reply, ret, state}
  end

  def handle_call({:stream_by_aggregate, {aggregate_module, aggregate_id}, version}, _from, state) do
    starting_at =
      case version do
        :all -> -1
        v -> String.to_integer(v)
      end

    query =
      from(
        e in DomainEvents,
        join: a in Aggregate,
        where: a.id == e.aggregate_id,
        where: a.aggregate == ^aggregate_module,
        where: a.aggregate_id == ^aggregate_id,
        where: e.aggregate_version > ^starting_at,
        order_by: e.aggregate_version,
        select: %{
          version: e.version,
          aggregate: {a.aggregate, a.aggregate_id},
          domain_event: e.domain_event,
          aggregate_version: e.aggregate_version,
          created: e.created
        }
      )

    ret = fn fun ->
      Repo.transaction(fn ->
        query
        |> Repo.stream()
        |> Stream.map(&build_record/1)
        |> fun.()
      end)
    end

    {:reply, ret, state}
  end

  # Internal functions

  defp get_aggregate({aggregate, id}) do
    case Repo.get_by(Aggregate, aggregate: aggregate, aggregate_id: id) do
      nil -> %Aggregate{aggregate: aggregate, aggregate_id: id}
      a -> a
    end
  end

  defp build_record(row) do
    EventRecord.create(
      domain_event(row.domain_event, row.aggregate),
      row.aggregate,
      "#{row.version}",
      "#{row.aggregate_version}"
    )
  end

  defp aggregate_table_id(aggregate) do
    aggregate
    |> get_aggregate()
    |> Aggregate.changeset()
    |> Repo.insert_or_update!()
    |> Map.get(:id)
  end

  defp do_append(aggregate, events) do
    {records, _version, aggregate_version} = from_enum(events, aggregate)

    Repo.insert_all(
      DomainEvents,
      Enum.map(records, &insert_event(&1, aggregate_table_id(aggregate)))
    )

    {:ok, aggregate_version, records}
  end

  defp insert_event(record, aggregate_id) do
    json =
      record.domain_event.__struct__
      |> Atom.to_string()
      |> Kernel.<>(Jason.encode!(record.domain_event))

    %{
      aggregate_id: aggregate_id,
      domain_event: :erlang.term_to_binary(record.domain_event, compressed: @domain_event_compression),
      domain_event_json: json,
      aggregate_version: String.to_integer(record.aggregate_version),
      version: String.to_integer(record.version),
      created: record.created_at |> from_timestamp() |> DateTime.from_erl()
    }
  end

  defp next_version(version) do
    case version do
      :empty -> "0"
      v -> "#{String.to_integer(v) + 1}"
    end
  end

  defp store_version do
    query =
      from(
        e in DomainEvents,
        select: e.version,
        order_by: [desc: e.version],
        limit: 1
      )

    case Repo.one(query) do
      nil -> :empty
      v -> "#{v}"
    end
  end

  defp aggregate_version({aggregate_module, aggregate_id}) do
    query =
      from(
        e in DomainEvents,
        join: a in Aggregate,
        where: e.aggregate_id == a.id,
        where: a.aggregate == ^aggregate_module,
        where: a.aggregate_id == ^aggregate_id,
        order_by: [desc: e.aggregate_version],
        select: e.aggregate_version,
        limit: 1
      )

    case Repo.one(query) do
      nil -> :empty
      version -> "#{version}"
    end
  end

  defp from_timestamp(timestamp) do
    timestamp
    |> Kernel.+(@epoch)
    |> :calendar.gregorian_seconds_to_datetime()
  end

  defp from_enum(events, aggregate) do
    events
    |> Enum.reduce({[], store_version(), aggregate_version(aggregate)}, fn e,
                                                                           {records, st_version,
                                                                            agg_version} ->
      {
        records ++
          [EventRecord.create(e, aggregate, next_version(st_version), next_version(agg_version))],
        next_version(st_version),
        next_version(agg_version)
      }
    end)
  end

  def domain_event(event, aggregate) do
    :erlang.binary_to_term(event)
  rescue
    _ ->
      Logger.error(
        "could not load some events for " <>
          "#{inspect(aggregate)} from the " <> "store. Possible data corruption."
      )

      nil
  end
end
