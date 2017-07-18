defmodule Chronik.Store.Adapters.ETS do
  @moduledoc false

  use GenServer

  alias Chronik.EventRecord

  @behaviour Chronik.Store

  @name  __MODULE__
  @table __MODULE__

  require Logger

  # API

  def child_spec(_store, opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, opts},
      type: :worker,
      restart: :permanent
    }
  end


  defp do_append(stream, events, record_version, opts  \\ [version: :any]) do
    {current_records, current_offset} =
      case get_stream(stream) do
        :not_found ->
          {[], -1}
        records ->
          # FIXME: Use another data type for storing events instead of List
          {records, records |> List.last |> Map.get(:offset)}
      end
    new_records = from_enum(stream, current_offset + 1, events, record_version)
    Logger.debug ["[#{inspect __MODULE__}<#{inspect stream}>] ",
                  "appending events: #{inspect events}."]
    case Keyword.get(opts, :version) do
      :no_stream when current_offset == -1 ->
        insert_records(stream, new_records)
      :any ->
        append_records(stream, current_records, new_records)
      version when is_number(version) and current_offset == version ->
        append_records(stream, current_records, new_records)
      _ ->
        {:error, "wrong expected version"}
    end
  end

  def append(stream, events, opts \\ [version: :any]) do
    GenServer.call(@name, {:append, stream, events, opts})
  end

  def fetch(stream, offset \\ :all) when offset >= 0 or offset == :all do
    GenServer.call(@name, {:fetch, stream, offset})
  end

  def handle_call({:fetch, stream, offset}, _from, state) do
    public_topics = Keyword.fetch!(state, :public_topics)
    record_version = Keyword.fetch!(state, :record_version)
    result =
      case get_stream(stream) do
        :not_found ->
          {:error, "`#{inspect stream}` stream not found"}
        current_records when offset == :all ->
          {:ok, length(current_records) - 1, Enum.to_list(current_records)}
        current_records ->
          new_records  =
            current_records
            |> Stream.filter(&(&1.offset > offset))
            |> Enum.to_list
          {:ok, offset + length(new_records), new_records}
      end
    {:reply, result, state}
  end

  def handle_call({:append, stream, events, opts}, _from, state) do
    public_topics = Keyword.fetch!(state, :public_topics)
    record_version = Keyword.fetch!(state, :record_version)
    # First write the public events
    public_records =
      if map_size(public_topics) > 0 do
        # If there are public topics
        # Check every event to see if it should be published
        # on those topics
        Enum.reduce(events, [],
          fn (event, records) ->
            event_type = event.__struct__
            case Map.fetch(public_topics, event_type) do
              {:ok, topic} ->
                {:ok, _, new_records} = do_append(topic, [event], record_version)
                new_records ++ records
              _ -> records
            end
          end)
      else
        # No public topics
        []
      end
    # Then write the events on the aggregate stream
    reply =
      case do_append(stream, events, record_version, opts) do
        {:ok, offset, aggregate_records} ->
          {:ok, offset, public_records ++ aggregate_records}

        error -> error
      end
    {:reply, reply, state}
  end
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  # GenServer callbacks

  def init([_store, opts]) do
    try do
      :ets.new(@table, [:set, :named_table, :public])
      public_topics = Keyword.get(opts, :public_topics, %{})
      record_version = Keyword.get(opts, :record_version, "1")
      {:ok, [public_topics: public_topics, record_version: record_version]}
    rescue
      _ -> {:stop, {:error, "event store already started"}}
    end
  end

  # Internal functions

  defp get_stream(stream) do
    case :ets.lookup(@table, stream) do
      [] -> :not_found
      [{^stream, records}] -> records
    end
  end

  defp insert_records(stream, records) do
    true = :ets.insert(@table, {stream, records})
    last = List.last(records)
    {:ok, last.offset, records}
  end

  defp append_records(stream, current_records, records) do
    new_records = current_records ++ records
    true = :ets.insert(@table, {stream, new_records})
    last = List.last(new_records)
    {:ok, last.offset, records}
  end

  defp from_enum(stream, offset, events, record_version) do
    {records, _} = Enum.reduce(events, {[], offset},
      fn (elem, {records, next_offset}) ->
        {[EventRecord.create(stream, next_offset, elem, record_version) | records], next_offset + 1}
      end)
    Enum.reverse(records)
  end
end
