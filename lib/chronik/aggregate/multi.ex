defmodule Chronik.Aggregate.Multi do
  @moduledoc """
  `Chronik.Aggregate.Multi` can be used to generate a single commmand
  that affects multiple entities.

  As can be seen on the test a multiple-entity command can be defined
  as:

  ## Example

  ```
  alias Chronik.Aggregate.Multi

  def handle_command({:update_name_and_max, name, max}, %Counter{id: id} = state) do
    state
    |> Multi.new(__MODULE__)
    |> Multi.delegate(&(&1.name), &rename(&1, id, name))
    |> Multi.delegate(&(&1.max), &update_max(&1, id, max))
    |> Multi.run()
  end
  ```

  This command affects both the `:name` entity and the `:max` entity
  in a transaction like manner. The `update_max/3` receives the
  updated aggregate state.
  """

  alias Chronik.Aggregate

  @type monad_state :: {Aggregate.state, [Chronik.domain_event], module}

  @doc "Create a new state for a multi-entity command."
  @spec new(state :: Aggregate.state, module :: module) :: monad_state
  def new(state, module), do: {state, [], module}

  @doc """
  Applies `val_fun` on a given entity.

  The state of the entity is obtained using the `lens_fun` function.
  """
  @spec delegate(ms :: monad_state, lens :: fun, val_fun :: fun) :: monad_state
  def delegate({state, events, module}, lens_fun, val_fun) when is_function(lens_fun) and is_function(val_fun) do
    new_events =
      state
      |> lens_fun.()
      |> val_fun.()
      |> List.wrap()

    {apply_events(new_events, state, module), events ++ new_events, module}
  end

  @doc "Applies the `val_fun` function on the aggregate state."
  @spec validate(ms :: monad_state, val_fun :: fun) :: monad_state
  def validate({state, events, module}, val_fun) do
    new_events =
      state
      |> val_fun.()
      |> List.wrap()

    {apply_events(new_events, state, module), events ++ new_events, module}
  end

  @doc """
  Run a concatenation of entities updates and return the domain events
  generated.
  """
  @spec run(ms :: monad_state) :: [Chronik.domain_event]
  def run({_state, events, _module}), do: events

  # Internal functions

  defp apply_events(events, state, module) when is_atom(module) do
    Enum.reduce(events, state, &module.handle_event/2)
  end
end
