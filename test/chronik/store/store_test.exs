defmodule Chronik.Store.Test do
  use ExUnit.Case
  alias DomainEvents.{CounterCreated, CounterIncremented}

  setup_all do
    {store, _pub_sub} = Chronik.Config.fetch_adapters()
    {:ok, %{store: store}}
  end

  test "insert events", %{store: store} do
    aggregate = {:test_aggregate, "1"}

    assert {:ok, :empty, []} = store.fetch()
    # Test that events can be appended to the Store
    assert {:ok, version, [_, _]} = store.append(aggregate,
      [%CounterCreated{id: "11", initial_value: 0},
       %CounterIncremented{id: "11", increment: 3}], version: :any)

    # If the stream exists and appending with version: :no_stream an error
    # should occurr
    assert {:error, "wrong expected version"} =
      store.append(aggregate,
        [%CounterCreated{id: "11", initial_value: 0}], version: :no_stream)

    # Check that the Store is on version 1 (since two events were appended)
    assert {:ok, _new_version, _} = store.append(aggregate,
      [%CounterIncremented{id: "11", increment: 3}], version: version)

    # Check now that the Store version is not 1 anymore
    assert {:error, "wrong expected version"} =
      store.append(aggregate, [nil], version: version)

    aggregate = {:test_aggregate, "2"}
    events =
      [%CounterCreated{id: "3", initial_value: 0},
       %CounterIncremented{id: "3", increment: 3},
       %CounterIncremented{id: "3", increment: 3}]

    # Append three events and remember the current_version of the Store
    {:ok, last_version, _} = store.append(aggregate, events, version: :any)

    # Check that nothing new is returnd from the last_version
    assert {:ok, ^last_version, []} =
      store.fetch_by_aggregate(aggregate, last_version)

    # Check that the last event is returned if we fetch from version
    assert {:ok, _version, [%{domain_event:
      %CounterIncremented{id: "3", increment: 3}}]} =
      store.fetch_by_aggregate(aggregate, version)

    # Fecth all stored records and keep the data field
    data_list =
      aggregate
      |> store.fetch_by_aggregate()
      |> elem(2)
      |> Enum.map(&(&1.domain_event))

    # Check that we got all events
    assert events = data_list

    # Fetch from the second on
    data_list =
      aggregate
      |> store.fetch_by_aggregate(version)
      |> elem(2)
      |> Enum.map(&(&1.domain_event))

    # Check that the second (included) and all the rests were fetched
    assert [List.last(events)] == data_list

    # Test that events above certain number returns the recent version
    assert {:ok, version, _} = store.fetch()
    assert version != :empty
    assert {:ok, ^version, []} = store.fetch(1000)
    assert version != 1000

    {error, _} = store.start_link([store, []])
    assert error != :ok
  end
end
