defmodule Example.DomainEvents do
  @moduledoc "These are the possible domain events."
  import Chronik.Macros

  defevent(CartCreated, [:id])
  defevent(ItemsAdded, [:id, :item_id, :quantity])
  defevent(ItemsRemoved, [:id, :item_id, :quantity])
end
