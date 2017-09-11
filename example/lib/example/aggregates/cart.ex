defmodule Example.Cart do
  @moduledoc "This a the Cart aggregate."
  use Chronik.Aggregate

  import Chronik.Macros

  alias Example.Cart
  alias Example.DomainEvents.{CartCreated, ItemsAdded, ItemsRemoved}

  defstruct [
    id: nil,
    items: %{}
  ]

  ##
  ## Cart commands
  ##
  defcommand create(id) do
    fn state ->
      state
      |> execute(&create_validator(&1, id))
    end
  end

  defcommand add_items(id, item_id, quantity) do
    fn state ->
      state
      |> execute(&add_items_validator(&1, id, item_id, quantity))
    end
  end

  defcommand remove_items(id, item_id, quantity) do
    fn state ->
      state
      |> execute(&remove_items_validator(&1, id, item_id, quantity))
    end
  end

  ##
  ## State transition
  ##
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

  ##
  ## Exceptions
  ##
  defmodule CartExistsError do
    defexception [:message]
  end

  defmodule CartEmptyError do
    defexception [:message]
  end

  ##
  ## Internal functions
  ##
  defp create_validator(nil, id) do
    %CartCreated{id: id}
  end
  defp create_validator(_state, _id) do
    raise CartExistsError, "Cart already created"
  end

  defp add_items_validator(_state, id, item_id, quantity) do
    %ItemsAdded{id: id, item_id: item_id, quantity: quantity}
  end

  defp remove_items_validator(state, id, item_id, quantity) do
    current_quantity = (state.items[item_id] || 0)
    if current_quantity >= quantity do
      %ItemsRemoved{id: id, item_id: item_id, quantity: quantity}
    else
      raise CartEmptyError, "Cannot remove items from cart #{id}"
    end
  end
end
