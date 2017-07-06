defmodule Chronik.Store.Adapters.ETS do
  @moduledoc false

  use GenServer

  alias Chronik.EventRecord

  @behaviour Chronik.Store

  @name  __MODULE__
  @table __MODULE__

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
    {current_events, current_offset} =
      case get_stream(stream) do
        :not_found ->
          {[], -1}
        current_events ->
          # FIXME: Use another data type for storing events instead of List
          {current_events, current_events |> List.last |> Map.get(:offset)}
      end

    case Keyword.get(opts, :version) do
      :any ->
        insert(stream, current_events ++ from_enum(stream, current_offset + 1, events))
      :no_stream when current_offset == -1 ->
        insert(stream, from_enum(stream, 0, events))
      version when is_number(version) and current_offset == version ->
        insert(stream, current_events ++ from_enum(stream, current_offset + 1, events))
      _ ->
        {:error, "wrong expected version"}
    end
  end

  def fetch(stream, offset \\ :all) when is_binary(stream) and (offset >= 0 or offset == :all) do
    case get_stream(stream) do
      :not_found ->
        {:error, "stream not found"}
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
  defp insert(stream, events) do
    true = :ets.insert(@table, {stream, events})
    last = List.last(events)
    {:ok, last.offset, events}
  end

  defp from_enum(stream, offset, data) do
    {events, _} = Enum.reduce(data, {[], offset},
      fn (elem, {events, next_offset}) ->
        {[EventRecord.create(stream, next_offset, elem) | events], next_offset + 1}
      end)
    Enum.reverse(events)
  end
end
