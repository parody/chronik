defmodule Chronik.Projection.Test do
  use ExUnit.Case

  @aggregate TestAggregate
  @projection Chronik.Projection.Test.KeepCount
  @projection_dump Chronik.Projection.Test.Dump

  alias DomainEvents.{CounterCreated, CounterIncremented}
  alias Chronik.EventRecord

  defmodule Dump do
    use Chronik.Projection.DumpToFile, filename: "./dump.log"
  end

  # This is a test projection. It receives domain events and keeps a
  # counter updated.
  defmodule KeepCount do
    use Chronik.Projection

    # Initially the projection state is nil
    def init(_opts), do: {nil, []}

    # When the conuter is created the state is the initial value
    def handle_event(%EventRecord{domain_event:
      %CounterCreated{id: id, initial_value: value}}, nil) do

      %{id => value}
    end
    def handle_event(%EventRecord{domain_event:
      %CounterCreated{id: id, initial_value: value}}, state) do

      Map.put(state,id, value)
    end

    # After an increment we transition to the sum
    # of the state and the increment.
    def handle_event(%EventRecord{domain_event:
      %CounterIncremented{id: id, increment: value}}, state) do

      Map.update!(state, id, &(&1 + value))
    end

    # Ignore other types of events.
    def handle_event(_e, state) do
      state
    end
  end

  setup_all do
    {store, pub_sub} = Chronik.Config.fetch_adapters()
    # store.start_link([store, []])
    # pub_sub.start_link([keys: :duplicate, name: pub_sub])
    {:ok, %{projection: @projection, store: store, pub_sub: pub_sub}}
  end

  # FIXME: Wait a while for the projection to transition to the next state.
  defp wait, do: Process.sleep(100)

  test "Normal flow of a projection",
    %{projection: projection, store: store, pub_sub: pub_sub} do

    aggregate          = {@aggregate, "3"}
    id = "10"
    initial_value   = 0
    increment_value = 3
    create_event    = %CounterCreated{id: id, initial_value: initial_value}
    increment_event = %CounterIncremented{id: id, increment: increment_value}

    # The first event is on the Store before the Projection is starts.
    assert {:ok, version, _} =
      store.append(aggregate, [create_event], [version: :no_stream])

    # We start the projection and start listening on the aggregate stream.
    # In this case an event is already recorded on the Store.
    assert {:ok, pid} = projection.start_link([])

    # Also start a projection that writes events to a file "dump.log"
    assert {:ok, _pid_dump} = @projection_dump.start_link([])

    # The state of the projection should be the initial value.
    assert initial_value == projection.state()[id]

    # Store a increment domain event on the Store.
    {:ok, version, records} =
      store.append(aggregate, [increment_event], [version: version])
    # and broadcast the new record to the PubSub.
    pub_sub.broadcast(records)
    wait()
    # Now the Projection state should be increment_value.
    assert ^increment_value = projection.state()[id]

    # Store a increment domain event on the Store.
    {:ok, _version, _records} =
      store.append(aggregate, [increment_event], [version: version])

    GenServer.stop(pid)

    # Load projection from store
    projection.start_link([])
    assert 6 == projection.state()[id]
  end
end
