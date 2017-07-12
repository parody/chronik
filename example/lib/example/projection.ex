defmodule Example.CartState do
  use Chronik.Projection

  alias Example.DomainEvents.{CartCreated, ItemsAdded, ItemsRemoved}

  def init(), do: nil

  # From the initial state we can only create the cart
  # Initially the cart is empty (no items of any type)
  def next_state(nil, %CartCreated{}) do
    %{}
  end

  # Removing a number of items only decrements that item quantity
  def next_state(items, %ItemsRemoved{item_id: item_id, quantity: quantity}) do
    current_quantity = (items[item_id] || 0)
    Map.put(items, item_id, current_quantity - quantity)
  end

  # Adding a number of items only increments that item quantity
  def next_state(items, %ItemsAdded{item_id: item_id, quantity: quantity}) do
    current_quantity = (items[item_id] || 0)
    Map.put(items, item_id, current_quantity + quantity)
  end
end
