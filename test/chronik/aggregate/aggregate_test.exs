defmodule Chronik.Aggregate.Test do
  use ExUnit.Case, async: false
  require Logger

  @aggregate Chronik.Aggregate.Test.Counter
  @increment 3

  # Counter is a test aggregate. It has only four commands:
  # create, increment, uppdate_name_and_max and destroy.
  defmodule Counter do
    @behaviour Chronik.Aggregate

    alias Chronik.Aggregate
    alias Chronik.Aggregate.Test.Counter
    alias DomainEvents.{
      CounterCreated,
      CounterIncremented,
      CounterNamed,
      CounterMaxUpdated,
      CounterDestroyed}

    # The aggregate state is just the counter, name and max, value.
    defstruct [
      :id,
      :counter,
      :name,
      :max
    ]

    # Public API for the Counter
    def create(id), do: Aggregate.command(__MODULE__, id, {:create, id})

    def increment(id, increment),
      do: Aggregate.command(__MODULE__, id, {:increment, increment})

    def update_name_and_max(id, name, max),
      do: Aggregate.command(__MODULE__, id,
        {:update_name_and_max, name, max})

    def destroy(id),
      do: Aggregate.command(__MODULE__, id, {:destroy})

    # This is only for debugging purposes
    def state(id), do: Aggregate.state(__MODULE__, id)

    # Counter command handlers
    def handle_command({:create, id}, nil) do
      %CounterCreated{id: id, initial_value: 0}
    end
    def handle_command({:create, id}, _state) do
       raise CartExistsError, "Cart #{inspect id} already created"
    end
    def handle_command({:increment, increment},
      %Counter{id: id, max: max, counter: counter})
      when counter + increment < max do

      %CounterIncremented{id: id, increment: increment}
    end
    def handle_command({:increment}, state) do
      raise "cannot increment counter on state #{inspect state}"
    end
    # This is an example of a multi-entity command.
    # It binds the execution of two state changes of two different
    # entities: name and max
    # The Aggregate.Multi takes care of binding the transitions
    # and rolling back to original state if some of the commands fail.
    def handle_command({:update_name_and_max, name, max}, %Counter{id: id} = state) do
      alias Chronik.Aggregate.Multi

      state
      |> Multi.new(__MODULE__)
      |> Multi.delegate(&(&1.name), &rename(&1, id, name))
      |> Multi.delegate(&(&1.max), &update_max(&1, id, max))
      |> Multi.run()
    end
    def handle_command({:update_name_and_max, _name, _max}, state) do
      raise "cannot update_name_and_max counter on state #{inspect state}"
    end
    def handle_command({:destroy}, %Counter{id: id}) do
      %CounterDestroyed{id: id}
    end
    def handle_command({:destroy}, state) do
      raise "cannot destroy counter on state #{inspect state}"
    end

    # This is the state transition function for the Counter.
    # From the initial nil state we go to a valid %Counter{} struct.
    def handle_event(%CounterCreated{id: id, initial_value: value}, nil) do
      %Counter{id: id, counter: value, max: 1000}
    end
    # We increment the %Counter{}.
    def handle_event(%CounterIncremented{id: id, increment: increment},
      %Counter{id: id, counter: counter}) do
      %Counter{id: id, counter: counter + increment}
    end
    def handle_event(%CounterNamed{name: name}, state) do
      put_in(state.name, name)
    end
    def handle_event(%CounterMaxUpdated{max: max}, state) do
      put_in(state.max, max)
    end
    # When we destroy the counter we go to a invalid state from which
    # we can not transition out.
    def handle_event(%CounterDestroyed{}, %Counter{}) do
      :destroyed
    end

    ##
    ## Internal function
    ##
    # This is a command validator on the name entity.
    defp rename(_name_state, id, name) do
      %CounterNamed{id: id, name: name}
    end

    # This is a command validator on the max entity.
    defp update_max(old_max, id, max) when max > old_max do
      %CounterMaxUpdated{id: id, max: max}
    end
    defp update_max(old_max, id, max) do
      raise "cannot reduce the max from #{old_max} to #{max} for counter #{id}"
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
    assert %{counter: @increment} = @aggregate.state(id)
  end

  test "Multiple-entity command using Aggregate.Multi" do
    id = "3"
    @aggregate.create(id)

    # This is a composed command to test the |> operator on executes
    assert :ok = @aggregate.update_name_and_max(id, "name", 10000)
    assert {:error, _} = @aggregate.update_name_and_max(id, "name2", 10)

    # If everything went fine we created and incremented in 3
    # the new @aggregate.
    assert %{max: 10000} = @aggregate.state(id)
    assert %{name: "name"} = @aggregate.state(id)
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

    # The unsupscription to the Regsitry is eventually consistent.
    # Wait a while to be sure.
    Process.sleep(100)

    # This command should bring the aggregate back up and replay from the
    # snapshot and replay the rest from the Store.
    assert :ok = @aggregate.increment(id, @increment)
    # This is a new process.
    assert pid != aggregate_pid({@aggregate, id})

    # The state is restored ok.
    assert %{counter: ^value} = @aggregate.state(id)
  end

  test "Shutdown timeout" do
    id        = "6"

    assert :ok = @aggregate.create(id)
    pid = aggregate_pid({@aggregate, id})

    # Wait for the aggregate to shutdown by a timeout.
    Process.sleep(5_000)

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
