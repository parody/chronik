defmodule Chronik.Store.Test do
  use ExUnit.Case, async: false

  setup_all do
    {store, _pub_sub} = Chronik.Config.fetch_adapters()
    store.init(nil)
    {:ok, %{store: store}}
  end

  test "insert events", %{store: store} do
    stream = "test_stream1"

    # Test that events can be appended to the Store
    assert {:ok, 1, [_, _]} = store.append(stream, [:event1, :event2], version: :any)

    # If the stream exists and appending with version: :no_stream an error 
    # should occurr
    assert {:error, "wrong expected version"} = store.append(stream, [:event1], version: :no_stream)

    # Check that the Store is on version 1 (since two events were appended)
    assert {:ok, _, _} = store.append(stream, [:event3], version: 1)

    # Check now that the Store version is not 1 anymore
    assert {:error, "wrong expected version"} = store.append(stream, [:event4], version: 1)
  end

  test "retrieve events", %{store: store} do
    stream = "test_stream2"
    events = [:event1, :event2, :event3]

    # Append three events and remember the current_offset of the Store
    {:ok, last_offset, _} = store.append(stream, events, version: :no_stream)

    # Check that nothing new is returnd from the last_offset
    assert {:ok, ^last_offset, []} = store.fetch(stream, last_offset)

    # Check that the last event is returned if we fetch from last_offset - 1
    assert {:ok, ^last_offset, [%{data: :event3}]} = 
      store.fetch(stream, last_offset - 1)

    # Fecth all stored records and keep the data field
    data_list =
      stream
      |> store.fetch
      |> elem(2)
      |> Enum.map(&(&1.data))

    # Check that we got all events
    assert events = data_list

    # Fetch from the second on
    data_list =
   	  stream
   	  |> store.fetch(0)
   	  |> elem(2)
   	  |> Enum.map(&(&1.data))

    # Check that the second (included) and all the rests were fetched
    assert (tl events) == data_list
  end

  test "singleton domain event store", %{store: store} do
    {error, _} = store.init(nil)
    assert error != :ok
  end
end
