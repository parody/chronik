ExUnit.start()
# DomainEvents used in the aggregate and projection tests.
defmodule DomainEvents do
  import Chronik.Macros

  defevent(CounterCreated, [:id, :initial_value])
  defevent(CounterIncremented, [:id, :increment])
  defevent(CounterDestroyed, [:id])
end

{store, pub_sub} = Chronik.Config.fetch_adapters()
store.start_link([store, []])
pub_sub.start_link([keys: :duplicate, name: pub_sub])
