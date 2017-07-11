defmodule Chronik.Aggregate.Test do
  use ExUnit.Case

  @aggregate Chronik.Aggregate.Test.Counter
  @store Chronik.Store.Adapters.ETS
  @pubsub Chronik.PubSub.Adapters.Registry

  defmodule Counter do
    use Chronik.Aggregate

    alias Chronik.Aggregate.Test.{Counter}

    defstruct [
      :id,
      :counter
    ]

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

    def create(nil, id) do
      %CounterCreated{id: id, initial_value: 0}  
    end

    def create(_state, _id) do
      fail "Already created counter"
    end

    def increment(%Counter{}, id, increment) do
      %CounterIncremented{id: id, increment: increment}  
    end

    def get_aggregate_id(%Counter{id: id}) do
      id
    end

    def next_state(nil, %CounterCreated{id: id, initial_value: value} ) do
      %Counter{id: id, counter: value}
      IO.inspect %Counter{id: id, counter: value}
    end
    
    def next_state(%Counter{id: id, counter: counter}, 
        %CounterIncremented{id: id, increment: increment}) do
      IO.inspect %Counter{id: id, counter: counter + increment}
    end

    def handle_command({:create, id}) do
      Counter.call(id,
        fn state ->
          execute(state, &Counter.create(&1, id))
        end)
    end

    def handle_command({:increment, id, increment}) do
      Counter.call(id,
        fn state ->
          execute(state, &Counter.increment(&1, id, increment))
        end)
    end

  end

  setup_all do
    {:ok, _} = @store.start_link([])
    {:ok, _} = @pubsub.start_link([keys: :duplicate, name: @pubsub])
    {:ok, %{aggregate: @aggregate}}
  end

  test "Double creating an aggregate", %{aggregate: aggregate} do
    id = "1"
    assert {:ok, 0, [_]} = aggregate.handle_command({:create, id})
    catch_error {:already_started, _} = aggregate.handle_command({:create, id})
  end

  test "Transition to next state", %{aggregate: aggregate} do
    id = "2"
    assert {:ok, 0, [_]} = aggregate.handle_command({:create, id})
    IO.inspect aggregate.handle_command({:create, id})
  end

end