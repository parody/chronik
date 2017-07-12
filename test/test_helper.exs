ExUnit.start()

# DomainEvents used in the aggregate and projection tests.
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
