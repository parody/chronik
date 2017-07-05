defmodule Chronik.Projection.Consumer do
  # use GenServer, restart: :transient
  # alias Chronik.PubSub
  # alias Chronik.Store
  # alias Chronik.EventRecord

  # def init(projection_id, projection_pid, streams \\ []) do
  #   for {stream, _offset} <- streams do
  #     :ok = PubSub.subscribe(stream)
  #   end

  #   cursors =
  #     streams
  #     |> Enum.map(
  #         fn {stream, offset} ->
  #           stream
  #           |> Store.fetch(offset)
  #           |> Enum.reduce(offset,
  #             fn {event, acc} ->
  #               send(projection_pid, {:next_state, event})
  #               {stream, event.offset}
  #             end)
  #         end)
  #     |> Enum.into(%{})

  #   {:ok, %{projection_pid: projection_pid, cursors: cursors}}
  # end

  # def handle_info(
  #   %EventRecord{stream: stream, offset: event_offset} = e,
  #   %{cursors: %{stream: consumer_offset}} = state)
  # do
  #   new_state =
  #     cond do
  #       event_offset == consumer_offset + 1 ->
  #         send(state.projection_pid, {:next_state, e.data})
  #         update_in(state.cursors[stream], event_offset)

  #       event_offset <= consumer_offset ->
  #         state

  #       event_offset > consumer_offset + 1 ->
  #         {:ok, new_offset, events} = Store.fetch(stream, consumer_offset)
  #         for event <- events, do:
  #           send(state.projection_pid, {:next_state, event})
  #         update_in(state.cursors[stream], new_offset)
  #     end
  #   {:noreply, new_state}
  # end

end