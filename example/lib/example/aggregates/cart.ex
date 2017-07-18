defmodule Example.Cart do
  
  defstruct [
    id: nil,
    items: %{}
  ]

  use Chronik.Aggregate

  import CommandMacro

  alias Example.Cart
  alias Example.DomainEvents.{CartCreated, ItemsAdded, ItemsRemoved}

  defmodule CartExistsError do
    defexception [:message]
  end

  defmodule CartEmptyError do
    defexception [:message]
  end

  command {:create, id}
  def create(nil, id) do
    %CartCreated{id: id}
  end
  def create(_state, _id) do
    raise CartExistsError, "Cart already created"
  end

  command {:add_items, id, item_id, quantity}
  def add_items(_state, id, item_id, quantity) do
    %ItemsAdded{id: id, item_id: item_id, quantity: quantity}
  end

  command {:remove_items, id, item_id, quantity}
  def remove_items(state, id, item_id, quantity) do
    current_quantity = (state.items[item_id] || 0)
    cond do
      current_quantity >= quantity ->
        %ItemsRemoved{id: id, item_id: item_id, quantity: quantity}
      true -> raise CartEmptyError, "Cannot remove items from cart #{id}"
    end

  end

  def next_state(nil, %CartCreated{id: id}) do
    %Cart{id: id}
  end

  def next_state(state, %ItemsAdded{item_id: item_id, quantity: quantity}) do
    current_quantity = (state.items[item_id] || 0) + quantity
    %{state | items: Map.put(state.items, item_id, current_quantity)}
  end

  def next_state(state, %ItemsRemoved{item_id: item_id, quantity: quantity}) do
    current_quantity = (state.items[item_id] || 0) - quantity
    %{state | items: Map.put(state.items, item_id, current_quantity)}
  end
end
