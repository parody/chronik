defmodule Chronik.Aggregate.Test do
  use ExUnit.Case

  @aggregate Chronik.Aggregate.Test.Counter
  @store Chronik.Store.Adapters.ETS
  @pubsub Chronik.PubSub.Adapters.Registry

  defmodule Counter do

    defstruct [
      :id,
      :counter
    ]

    use Chronik.Aggregate

    alias Chronik.Aggregate.Test.{Counter}

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
      raise "Already created counter"
    end

    def increment(%Counter{}, id, increment) do
      %CounterIncremented{id: id, increment: increment}  
    end

    def next_state(nil, %CounterCreated{id: id, initial_value: value}) do
      %Counter{id: id, counter: value}
    end
    
    def next_state(%Counter{id: id, counter: counter}, 
      %CounterIncremented{id: id, increment: increment}) do
      %Counter{id: id, counter: counter + increment}
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

    def handle_command({:create_and_increment, id, increment}) do
      Counter.call(id,
        fn state ->
          state
          |> execute(&Counter.create(&1, id))
          |> execute(&Counter.increment(&1, id, increment))
        end)
    end

  end

  setup_all do
    {:ok, _} = @store.start_link([])
    {:ok, _} = @pubsub.start_link([keys: :duplicate, name: @pubsub])
    {:ok, %{aggregate: @aggregate}}
  end

  test "Double creating an aggregate with meaniful error message", %{aggregate: aggregate} do
    id = "1"
    new_offset = 0
    assert {:ok, ^new_offset} = aggregate.handle_command({:create, id})
    assert {:error, _} = aggregate.handle_command({:create, id})
  end

  test "Transition to next state", %{aggregate: aggregate} do
    id = "2"
    increment = 3
    aggregate.handle_command({:create, id})
    assert {:ok, 1} = aggregate.handle_command({:increment, id, increment})
    assert {^aggregate, %{counter: ^increment}} = aggregate.get(id)
  end

  test "Multiple (using pipe operator) transition", %{aggregate: aggregate} do
    id = "3"
    increment = 3
    assert {:ok, 1} = aggregate.handle_command({:create_and_increment, id, increment})
    assert {^aggregate, %{counter: ^increment}} = aggregate.get(id)
  end

end