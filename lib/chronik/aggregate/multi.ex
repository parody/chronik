defmodule Chronik.Aggregate.Multi do
  @moduledoc """
  This module can be used to generate a commmand that affects multiple entities.

  As can be seen on the test a multiple-entity command can be defined as:
  ```
  def handle_command({:update_name_and_max, name, max},
    %Counter{id: id} = state) do

    alias Chronik.Aggregate.Multi

    state
    |> Multi.new(__MODULE__)
    |> Multi.delegate(&(&1.name), &rename(&1, id, name))
    |> Multi.delegate(&(&1.max), &update_max(&1, id, max))
    |> Multi.run()
  end
  ```

  This command affects both the `name` entity and the `max` entity in a
  transaction like manner. The `update_max` receives the updated aggregate
  state.
  """

  alias Chronik.Aggregate

  @type monad_state :: {Aggregate.state(), [Chronik.domain_event()], module()}

  @doc """
  Create a new state for a multi-entity command.
  """
  @spec new(state :: Aggregate.state(), module :: module()) :: monad_state
  def new(state, module), do: {state, [], module}

  @doc """
  Applies the `fun` function on a given entity. The state of the entity
  is obtained using the `lens` function.
  """
  @spec delegate(ms :: monad_state(), lens :: fun(), fun :: fun())
    :: monad_state()
  def delegate({state, events, module}, lens_fun, validator_fun) do
    new_events =
      state
      |> lens_fun.()
      |> validator_fun.()
      |> List.wrap()

    {apply_events(new_events, state, module), events ++ new_events, module}
  end

  @doc """
  Applies the `fun` function on the aggregate state.
  """
  @spec validate(ms :: monad_state(), fun :: fun())
    :: monad_state()
  def validate({state, events, module}, validator_fun) do
    new_events =
      state
      |> validator_fun.()
      |> List.wrap()

    {apply_events(new_events, state, module), events ++ new_events, module}
  end

  @doc """
  Run a concatenation of entities updates and return the domain events
  generated.
  """
  @spec run(ms :: monad_state()) :: [Chronik.domain_event]
  def run({_state, events, _module}), do: events

  defp apply_events(events, state, module) do
    Enum.reduce(events, state, &module.handle_event/2)
  end
end
