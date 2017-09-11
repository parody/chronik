defmodule Example.Projection.CartsState do
  @moduledoc "This projection keeps the cart state by adding and removing
  items to it."
  use Chronik.Projection

  alias Example.DomainEvents.{CartCreated, ItemsAdded, ItemsRemoved}
  alias Chronik.EventRecord

  # The initial state is nil.
  def init(_opts), do: {nil, []}

  # From the initial state we can only create the cart
  # Initially the cart is empty (no items of any type)
  def next_state(nil, %EventRecord{domain_event: %CartCreated{id: id}}) do
    %{id => %{}}
  end
  def next_state(carts, %EventRecord{domain_event: %CartCreated{id: id}}) do
    Map.put(carts, id, %{})
  end
  # Removing a number of items only decrements that item quantity
  def next_state(carts, %EventRecord{domain_event: %ItemsRemoved{id: id,
    item_id: item_id, quantity: quantity}}) do

    current_quantity = (carts[id][item_id] || 0)
    %{carts | id => Map.put(carts[id], item_id, current_quantity - quantity)}
  end

  # Adding a number of items only increments that item quantity
  def next_state(carts, %EventRecord{domain_event: %ItemsAdded{id: id,
    item_id: item_id, quantity: quantity}}) do

    current_quantity = (carts[id][item_id] || 0)
    %{carts | id => Map.put(carts[id], item_id, current_quantity + quantity)}
  end
end
