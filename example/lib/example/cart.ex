defmodule Example.Cart do
  
  defstruct [
    id: nil,
    items: %{}
  ]

  use Chronik.Aggregate

  alias Example.Cart
  alias Example.DomainEvents.{CartCreated, ItemsAdded, ItemsRemoved}

  def create(nil, id) do
    %CartCreated{id: id}
  end

  def create(_state, _id) do
    raise "Cart already created"
  end

  def remove_items(state, id, item_id, quantity) do
    current_quantity = (state.items[item_id] || 0)
    cond do
      current_quantity >= quantity ->
        %ItemsRemoved{id: id, item_id: item_id, quantity: quantity}
      true -> raise "Cannot remove items from cart #{id}"
    end

  end

  def add_items(_state, id, item_id, quantity) do
    %ItemsAdded{id: id, item_id: item_id, quantity: quantity}
  end

  def handle_command({:create, id}) do
    Cart.call(id,
    fn state ->
      execute(state, &Cart.create(&1, id))
    end)
  end

  def handle_command({:add_items, id, item_id, quantity}) do
    Cart.call(id,
    fn state ->
      execute(state, &Cart.add_items(&1, id, item_id, quantity))
    end)
  end

  def handle_command({:remove_items, id, item_id, quantity}) do
    Cart.call(id,
    fn state ->
      execute(state, &Cart.remove_items(&1, id, item_id, quantity))
    end)
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