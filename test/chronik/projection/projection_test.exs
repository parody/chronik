defmodule Chronik.Projection.Test do
  use ExUnit.Case, async: false

  @aggregate TestAggregate
  @projection Chronik.Projection.Test.KeepCount
  
  alias DomainEvents.{CounterCreated, CounterIncremented}

  # This is a test projection. It receives domain events and keeps a
  # counter updated.
  defmodule KeepCount do
    use Chronik.Projection

    # Initially the projection state is nil
    def init(), do: nil

    # When the conuter is created the state is the initial value
    def next_state(nil, %CounterCreated{initial_value: value}) do
      value
    end

    # After an increment we transition to the sum
    # of the state and the increment.
    def next_state(state, %CounterIncremented{increment: value}) do
      state + value
    end
  end

  setup_all do
    {store, pub_sub} = Chronik.Config.fetch_adapters()
    {:ok, _pid} = store.start_link([store, []])
    {:ok, _pid} = pub_sub.start_link([keys: :duplicate, name: pub_sub])
    {:ok, %{projection: @projection, store: store, pub_sub: pub_sub}}
  end

  # FIXME: Wait a while for the projection to transition to the next state.
  defp wait, do: Process.sleep(100)

  test "Normal flow of a projection",
    %{projection: projection, store: store, pub_sub: pub_sub} do

    aggregate_id    = "1"
    stream          = {@aggregate, aggregate_id}
    initial_value   = 0
    increment_value = 3
    create_event    = %CounterCreated{id: "1", initial_value: initial_value}
    increment_event = %CounterIncremented{id: "2", increment: increment_value}

    # The first event is on the Store before the Projection is startes.
    assert {:ok, offset, _records} = store.append(stream, [create_event])

    # We start the projection and start listening on the aggregate stream.
    # In this case an event is already recorded on the Store.
    assert {:ok, _pid} = projection.start_link([{@aggregate, aggregate_id, :all}])

    # The state of the projection should be the initial value.
    assert ^initial_value = projection.state()

    # Store a increment domain event on the Store.
    next_offset = offset + 1
    assert {:ok, ^next_offset, records} =
      store.append(stream, [increment_event], [version: offset])

    # and broadcast the new record to the PubSub.
    pub_sub.broadcast(stream, records)
    
    wait()

    # Now the Projection state should be increment_value.
    assert ^increment_value = projection.state()
  end

  test "Injecting future events",
    %{projection: projection, store: store, pub_sub: pub_sub} do

    aggregate_id    = "2"
    stream          = {@aggregate, aggregate_id}
    initial_value   = 0
    increment_value = 3
    create_event    = %CounterCreated{id: "1", initial_value: initial_value}
    increment_event = %CounterIncremented{id: "2", increment: increment_value}

    # Store an create domain event
    {:ok, _offset, _records} = store.append(stream, [create_event]) 

    # Start the projection
    projection.start_link([{@aggregate, aggregate_id, :all}])

    # Store a increment domain event
    {:ok, _next_offset, [record]} = store.append(stream, [increment_event])
    
    # Increment the offset of the last record. This is a future event for
    # the consumer module.
    fake_record = update_in(record.offset, &(&1 + 10))

    # Broadcast the fake_record
    pub_sub.broadcast(stream, [fake_record])

    wait()

    # The consumer will receive a record with offset > current_offset + 1
    # and will try to fetch the missing part of the stream from the store.
    # It will only find the event with offset = 1 and apply it to the
    # projection
    assert ^increment_value = projection.state()
  end

  test "Injecting past events",
    %{projection: projection, store: store, pub_sub: pub_sub} do

    aggregate_id    = "3"
    stream          = {@aggregate, aggregate_id}
    initial_value   = 0
    create_event    = %CounterCreated{id: "1", initial_value: initial_value}

    # Store a create event on the Store
    {:ok, _offset, records} = store.append(stream, [create_event])

    # Start the projeciton. The consumer will find the create event already
    # on the store.
    projection.start_link([{@aggregate, aggregate_id, :all}])

    wait()

    # After fetching the create event from the Store the state should be zero.
    assert ^initial_value = projection.state()

    # Publish the create record again. The consumer will have already seen
    # it and should discard it.
    pub_sub.broadcast(stream, records)

    wait()

    # The create event should be ignored since the offset is older than the 
    # consumer offset.
    assert ^initial_value = projection.state()
  end
end