defmodule Chronik.Store.Adapters.ETS do
  @moduledoc """
  ETS event adapter
  """

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
          {current_events, current_events |> List.last |> Map.get(:event_number)}
      end

    case Keyword.get(opts, :version) do
      :any ->
        insert(stream, current_events ++ from_enum(stream, current_offset + 1, events))
      :no_stream when current_offset == 0 ->
        insert(stream, from_enum(stream, 0, events))
      version when is_number(version) and current_offset == version ->
        insert(stream, current_events ++ from_enum(stream, current_offset + 1, events))
      _ ->
        {:error, "wrong expected version"}
    end
  end

  def fetch(stream, offset \\ 0) when is_binary(stream) and offset >= 0 do
    case get_stream(stream) do
      :not_found ->
        {:error, "stream not found"}
      current_events when offset == 0 ->
        Stream.drop(current_events, offset) |> Enum.to_list
      current_events ->
        Stream.filter(current_events, fn(event) -> event.event_number >= offset end) |> Enum.to_list
        # Enum.at(current_events, offset, {:error, "event #{offset} not found"})
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
    {:ok, last.event_number + 1, events}
  end

  defp from_enum(stream, offset, data) do
    {events, _} = Enum.reduce(data, {[], offset},
      fn (elem, {events, next_offset}) ->
        {[EventRecord.create(stream, next_offset, elem) | events], next_offset + 1}
      end)
    Enum.reverse(events)
  end
end
