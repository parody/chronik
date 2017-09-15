ExUnit.start()
# DomainEvents used in the aggregate and projection tests.
defmodule DomainEvents do
  defmodule CounterCreated do
    defstruct [:id, :initial_value]
  end

  defmodule CounterIncremented do
    defstruct [:id, :increment]
  end

  defmodule CounterNamed do
    defstruct [:id, :name]
  end

  defmodule CounterMaxUpdated do
    defstruct [:id, :max]
  end

  defmodule CounterDestroyed do
    defstruct [:id]
  end
end

Chronik.Store.start_link()
Chronik.PubSub.start_link()
