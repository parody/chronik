defmodule Chronik.Projection.Test do
  use ExUnit.Case

  @store Chronik.Store.Adapters.ETS
  @aggregate TestAggregate
  @pubsub Chronik.PubSub.Adapters.Registry
  @projection Chronik.Projection.Test.KeepCount
  
  defmodule DomainEvents do
    defmodule CounterCreated do
      defstruct [
        :id,
        :initial_value
      ]
    end

    defmodule CounterIncremented do
      defstruct [
        :id,
        :increment
      ]
    end
  end

  alias DomainEvents.{CounterCreated, CounterIncremented}

  defmodule KeepCount do
    use Chronik.Projection

    def init(), do: nil

    def next_state(_state, %CounterCreated{initial_value: value}) do
      value
    end

    def next_state(state, %CounterIncremented{increment: value}) do
      state + value
    end
  end

  setup_all do
    {:ok, _} = @store.start_link([])
    {:ok, _} = @pubsub.start_link([keys: :duplicate, name: @pubsub])
    {:ok, %{projection: @projection}}
  end

  test "Normal flow of a projection", %{projection: projection} do
    aggregate_id = "1"
    stream = {@aggregate, aggregate_id}
    assert {:ok, offset, _} = @store.append(stream, 
      [%CounterCreated{id: "1", initial_value: 0}], [version: :no_stream])
    assert {:ok, _} = projection.start_link([{@aggregate, aggregate_id, :all}])
    assert 0 = projection.state()
    next_offset = offset + 1
    assert {:ok, ^next_offset, records} = @store.append(stream, 
      [%CounterIncremented{id: "2", increment: 3}], [version: offset])
    @pubsub.broadcast(stream, records)
    Process.sleep(100) 
    assert 3 = projection.state()
  end

  test "Injecting future events", %{projection: projection} do
    aggregate_id = "2"
    stream = {@aggregate, aggregate_id}
    assert {:ok, offset, _} = @store.append(stream, 
      [%CounterCreated{id: "1", initial_value: 0}], [version: :no_stream])
    assert {:ok, _} = projection.start_link([{@aggregate, aggregate_id, :all}])
    next_offset = offset + 1
    assert {:ok, ^next_offset, [record]} = @store.append(stream, 
     [%CounterIncremented{id: "2", increment: 3}], [version: offset])
    fake_record = update_in(record.offset, &(&1 + 1))
    @pubsub.broadcast(stream, [fake_record])
    Process.sleep(100)
    assert 3 = projection.state()
  end

  test "Injecting past events", %{projection: projection} do
    aggregate_id = "3"
    stream = {@aggregate, aggregate_id}
    assert {:ok, _offset, records} = @store.append(stream, 
      [%CounterCreated{id: "1", initial_value: 0}], [version: :no_stream])
    assert {:ok, _} = projection.start_link([{@aggregate, aggregate_id, :all}])
    @pubsub.broadcast(stream, records)
    Process.sleep(100)
    assert 0 = projection.state()
  end
end