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
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end

  def append(stream, events, opts \\ [version: :any]) do
    {current_records, current_offset} =
      case get_stream(stream) do
        :not_found ->
          {[], -1}
        records ->
          # FIXME: Use another data type for storing events instead of List
          {records, records |> List.last |> Map.get(:offset)}
      end
    new_records = from_enum(stream, current_offset + 1, events)
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

  def fetch(stream, offset \\ :all) when offset >= 0 or offset == :all do
    case get_stream(stream) do
      :not_found ->
        {:error, "`#{inspect stream}` stream not found"}
      current_events when offset == :all ->
        {:ok, length(current_events) - 1, Enum.to_list(current_events)}
      current_events ->
        events = 
          current_events
          |> Stream.filter(&(&1.offset > offset))
          |> Enum.to_list
        {:ok, offset + length(events), events}
    end
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [opts], name: @name)
  end

  # GenServer callbacks

  def init(_args) do
    try do
      {:ok, :ets.new(@table, [:set, :named_table, :public])}
    rescue
      _ -> {:stop, {:error, "event store already started"}}
    end
  end

  # Internal functions

  defp get_stream(stream) do
    case :ets.lookup(@table, stream) do
      [] -> :not_found
      [{^stream, events}] -> events
    end
  end

  # FIXME: might have an unintended effect due to a possible race condition
  defp insert_records(stream, records) do
    true = :ets.insert(@table, {stream, records})
    last = List.last(records)
    {:ok, last.offset, records}
  end

  # FIXME: might have an unintended effect due to a possible race condition
  defp append_records(stream, current_records, new_records) do
    true = :ets.insert(@table, {stream, current_records ++ new_records})
    last = List.last(new_records)
    {:ok, last.offset, new_records}
  end

  defp from_enum(stream, offset, data) do
    {events, _} = Enum.reduce(data, {[], offset},
      fn (elem, {events, next_offset}) ->
        {[EventRecord.create(stream, next_offset, elem) | events], next_offset + 1}
      end)
    Enum.reverse(events)
  end
end
