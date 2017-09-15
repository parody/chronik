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

{store, pub_sub} = Chronik.Config.fetch_adapters()
store.start_link([store, []])
pub_sub.start_link([keys: :duplicate, name: pub_sub])
