defmodule Chronik.Aggregate.Test do
  use ExUnit.Case, async: false

  @aggregate Chronik.Aggregate.Test.Counter
  # Counter is a test aggregate. It has only two commands
  # :create and :increment.

  defmodule Counter do

    # The aggregate state is just the counter value.
    defstruct [
      :id,
      :counter
    ]

    use Chronik.Aggregate

    alias Chronik.Aggregate.Test.{Counter}
    alias DomainEvents.{CounterCreated, CounterIncremented}

    # From a nil state we can create a counter.
    def create(nil, id) do
      %CounterCreated{id: id, initial_value: 0}
    end

    # If we try to create a counter from a non-nil state we raise an error.
    def create(_state, _id) do
      raise "Already created counter"
    end

    # The increment command is valid on every non-nil state
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
    {store, pub_sub} = Chronik.Config.fetch_adapters()
    {:ok, _} = store.start_link([store, []])
    {:ok, _} = pub_sub.start_link([keys: :duplicate, name: pub_sub])
    {:ok, %{aggregate: @aggregate}}
  end

  test "Double creating an aggregate", %{aggregate: aggregate} do
    id         = "1"

    # Check that we can creante an aggregate.
    assert :ok = aggregate.handle_command({:create, id})

    # Re-creating should return an error.
    assert {:error, _} = aggregate.handle_command({:create, id})
  end

  test "Transition to next state", %{aggregate: aggregate} do
    id        = "2"
    increment = 3

    aggregate.handle_command({:create, id})

    # We can handle the increment command correctly.
    assert :ok = aggregate.handle_command({:increment, id, increment})

    # The resulting state is 3.
    assert {^aggregate, %{counter: ^increment}} = aggregate.get(id)
  end

  test "Multiple (using pipe operator) transition", %{aggregate: aggregate} do
    id        = "3"
    increment = 3

    # This is a composed command to test the |> operator on executes
    aggregate.handle_command({:create_and_increment, id, increment})

    # If everything went fine we created and incremented in 3 the new aggregate.
    assert {^aggregate, %{counter: ^increment}} = aggregate.get(id)
  end

  test "Command on unexistent aggregate", %{aggregate: aggregate} do
    id        = "4"
    increment = 3

    assert {:error, _} = aggregate.handle_command({:increment, id, increment})
  end

end