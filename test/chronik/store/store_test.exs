defmodule Chronik.Store.Test do
  use ExUnit.Case
  alias DomainEvents.{CounterCreated, CounterIncremented}

  defmodule TestStore do
    use Chronik.Store, otp_app: :chronik

    def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker
    }
  end

    defoverridable child_spec: 1
  end

  setup_all do
    TestStore.start_link([])
    :ok
  end

  test "insert events" do
    aggregate = {:test_aggregate, "1"}

    assert {:ok, :empty, []} = TestStore.fetch()

    assert :empty == TestStore.current_version()

    # Test that events can be appended to the Store
    assert {:ok, version, [_, _]} = TestStore.append(aggregate,
      [%CounterCreated{id: "11", initial_value: 0},
       %CounterIncremented{id: "11", increment: 3}], version: :any)

    assert :empty != TestStore.current_version()

    # If the stream exists and appending with version: :no_stream an error
    # should occurr
    assert {:error, "wrong expected version"} =
      TestStore.append(aggregate,
        [%CounterCreated{id: "11", initial_value: 0}], version: :no_stream)

    # Check that the Store is on version 1 (since two events were appended)
    assert {:ok, _new_version, _} = TestStore.append(aggregate,
      [%CounterIncremented{id: "11", increment: 3}], version: version)

    # Check now that the Store version is not 1 anymore
    assert {:error, "wrong expected version"} =
      TestStore.append(aggregate, [nil], version: version)

    aggregate = {:test_aggregate, "2"}
    events =
      [%CounterCreated{id: "3", initial_value: 0},
       %CounterIncremented{id: "3", increment: 3},
       %CounterIncremented{id: "3", increment: 3}]

    # Append three events and remember the current_version of the Store
    {:ok, last_version, _} = TestStore.append(aggregate, events, version: :any)

    # Check that nothing new is returnd from the last_version
    assert {:ok, ^last_version, []} =
      TestStore.fetch_by_aggregate(aggregate, last_version)

    # Check that the last event is returned if we fetch from version
    assert {:ok, _version, [%{domain_event:
      %CounterIncremented{id: "3", increment: 3}}]} =
      TestStore.fetch_by_aggregate(aggregate, version)

    # Fecth all stored records and keep the data field
    data_list =
      aggregate
      |> TestStore.fetch_by_aggregate()
      |> elem(2)
      |> Enum.map(&(&1.domain_event))

    # Check that we got all events
    assert events = data_list

    # Fetch from the second on
    data_list =
      aggregate
      |> TestStore.fetch_by_aggregate(version)
      |> elem(2)
      |> Enum.map(&(&1.domain_event))

    # Check that the second (included) and all the rests were fetched
    assert [List.last(events)] == data_list

    # Test that events above certain number returns the recent version
    assert {:ok, version, _} = TestStore.fetch()
    assert version != :empty
    assert {:ok, ^version, []} = TestStore.fetch("1000")
    assert version != "1000"

    # Test Store streaming functionality
    f = fn stream ->
      stream
      |> Enum.reduce(0, fn _, acc -> acc + 1 end)
    end

    assert 0 < TestStore.stream(f)
  end
end
