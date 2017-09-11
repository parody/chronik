defmodule Chronik.Aggregate.Test do
  use ExUnit.Case, async: false

  @aggregate Chronik.Aggregate.Test.Counter
  @increment 3

  # Counter is a test aggregate. It has only four commands:
  # create, increment, create_increment and destroy.
  defmodule Counter do
    use Chronik.Aggregate, shutdown_timeout: 5000, snapshot_every: 4

    import Chronik.Macros

    alias Chronik.Aggregate.Test.Counter
    alias DomainEvents.{CounterCreated, CounterIncremented, CounterDestroyed}

    # The aggregate state is just the counter value.
    defstruct [
      :id,
      :counter
    ]

    # This command creates a counter.
    defcommand create(id) do
      fn state ->
        state
        |> execute(&create_validator(&1, id))
      end
    end

    # Increment the counter given by id.
    defcommand increment(id, increment) do
      fn state ->
        execute(state, &increment_validator(&1, id, increment))
      end
    end

    # This is an example of a compesed command. It binds the execution
    # of two commands.
    defcommand create_and_increment(id, increment) do
      fn state ->
        state
        |> execute(&create_validator(&1, id))
        |> execute(&increment_validator(&1, id, increment))
      end
    end

    # Destroy a counter.
    defcommand destroy(id) do
      fn state ->
        state
        |> execute(&destroy_validator(&1))
      end
    end

    # This is the state transition function for the Counter.
    # From the initial nil state we go to a valid %Counter{} struct.
    def next_state(nil, %CounterCreated{id: id, initial_value: value}) do
      %Counter{id: id, counter: value}
    end
    # We increment the %Counter{}.
    def next_state(%Counter{id: id, counter: counter},
      %CounterIncremented{id: id, increment: increment}) do
      %Counter{id: id, counter: counter + increment}
    end
    # When we destroy the counter we go to a invalid state from which
    # we can not transition out.
    def next_state(%Counter{}, %CounterDestroyed{}) do
      :deleted
    end

    ##
    ## Commands validators
    ##
    # From a nil state we can create a counter.
    defp create_validator(nil, id) do
      %CounterCreated{id: id, initial_value: 0}
    end
    # If we try to create a counter from a non-nil state we raise an error.
    defp create_validator(_state, _id) do
      raise "already created counter"
    end

    # The increment command is valid on every non-nil state
    defp increment_validator(%Counter{}, id, increment) do
      %CounterIncremented{id: id, increment: increment}
    end
    defp increment_validator(_stte, _id, _increment) do
      raise "cannot increment unexisting counter"
    end

    # We can destroy a counter from any state
    defp destroy_validator(%Counter{} = state) do
      %CounterDestroyed{id: state.id}
    end
    # except from a already deleted counter
    defp destroy_validator(:deleted) do
      raise "counter already destroyed"
    end
  end

  test "Double creating an aggregate" do
    id  = "1"

    # Check that we can creante an counter aggregate.
    # This test may failed if there is a snapshot or events in the Store.
    assert :ok = @aggregate.create(id)

    # Re-creating should return an error.
    assert {:error, _} = @aggregate.create(id)

    # We can destroy a counter
    assert :ok = @aggregate.destroy(id)
  end

  test "Transition to next state" do
    id = "2"

    @aggregate.create(id)

    # We can handle the increment command correctly.
    assert :ok = @aggregate.increment(id, @increment)

    # The resulting state is 3.
    assert %{counter: @increment} = @aggregate.get(id)
  end

  test "Multiple (using pipe operator) transition" do
    id = "3"

    # This is a composed command to test the |> operator on executes
    @aggregate.create_and_increment(id, @increment)

    # If everything went fine we created and incremented in 3 the new @aggregate.
    assert %{counter: @increment} = @aggregate.get(id)
  end

  test "Command on unexisting aggregate" do
    id = "4"

    # Counter with id 4 does not exists.
    assert {:error, _} = @aggregate.increment(id, @increment)
  end

  test "Aggregate snapshot and replay of events" do
    id        = "5"
    times = 10
    value = @increment * (times + 1)

    assert :ok = @aggregate.create(id)

    # The aggregate is configured to save a snapshot every 4 events.
    # So two snapshots should happen here. The last one is only kept in
    # the Store.
    for _ <- 1..times,
      do: assert :ok = @aggregate.increment(id, @increment)

    # Take down the aggregate
    pid = aggregate_pid({@aggregate, id})
    GenServer.stop(pid, :normal)
    assert false == Process.alive?(pid)

    # This command should bring the aggregate back up and replay from the
    # snapshot and replay the rest from the Store.
    assert :ok = @aggregate.increment(id, @increment)
    # This is a new process.
    assert pid != aggregate_pid({@aggregate, id})

    # The state is restored ok.
    assert %{counter: ^value} = @aggregate.get(id)
  end

  test "Shutdown timeout" do
    id        = "6"

    assert :ok = @aggregate.handle_command({:create, id})
    pid = aggregate_pid({@aggregate, id})

    # Wait for the aggregate to shutdown by a timeout.
    Process.sleep(10_000)

    # The aggregate is down.
    assert false == Process.alive?(pid)
  end

  # Get the pid for a given aggregate from the Regsitry.
  defp aggregate_pid(aggregate) do
    Chronik.AggregateRegistry
    |> Registry.lookup(aggregate)
    |> hd()
    |> elem(0)
  end
end
