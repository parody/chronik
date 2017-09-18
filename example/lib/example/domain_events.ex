defmodule Example.DomainEvents do
  @moduledoc "These are the possible domain events."
  defmodule CartCreated, do: defstruct [:id]
  defmodule ItemsAdded, do: defstruct [:id, :item_id, :quantity]
  defmodule ItemsRemoved, do: defstruct [:id, :item_id, :quantity]
end
