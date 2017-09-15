defmodule Example.Cart do
  @moduledoc "This a the Cart aggregate."
  use Chronik.Aggregate

  alias Chronik.Aggregate
  alias Example.Cart
  alias Example.DomainEvents.{CartCreated, ItemsAdded, ItemsRemoved}

  ##
  ## Aggregate State
  ##
  defstruct [
    id: nil,
    items: %{}
  ]

  ##
  ## Public API Cart commands
  ##
  def create(id), do: Aggregate.command(__MODULE__, id, {:create, id})

  def add_items(id, item_id, quantity),
    do: Aggregate.command(__MODULE__, id, {:add_items, item_id, quantity})

  def remove_items(id, item_id, quantity),
    do: Aggregate.command(__MODULE__, id, {:remove_items, item_id, quantity})

  ##
  ## Command validators
  ##
  def handle_command({:create, id}, nil) do
    %CartCreated{id: id}
  end
  def handle_command({:create, id}, _state) do
    raise CartExistsError, "Cart #{id} already created"
  end
  def handle_command({:add_items, item_id, quantity}, %Cart{id: id}) do
    %ItemsAdded{id: id, item_id: item_id, quantity: quantity}
  end
  def handle_command({:remove_items, item_id, quantity}, %Cart{id: id, items: items}) do
    current_quantity = (items[item_id] || 0)
    if current_quantity >= quantity do
      %ItemsRemoved{id: id, item_id: item_id, quantity: quantity}
    else
      raise CartEmptyError, "Cannot remove items from cart #{id}"
    end
    end
  def handle_command({cmd, _item_id, _quantity}, _state)
    when cmd in ~w(add_items remove_items)a do

    raise CartEmptyError, "Cart already created"
  end

  ##
  ## State transition
  ##
  def handle_event(%CartCreated{id: id}, nil) do
    %Cart{id: id}
  end
  def handle_event(%ItemsAdded{item_id: item_id, quantity: quantity}, state) do
    current_quantity = (state.items[item_id] || 0) + quantity
    %{state | items: Map.put(state.items, item_id, current_quantity)}
  end
  def handle_event(%ItemsRemoved{item_id: item_id, quantity: quantity}, state) do
    current_quantity = (state.items[item_id] || 0) - quantity
    %{state | items: Map.put(state.items, item_id, current_quantity)}
  end

  ##
  ## Used for debugging purposes
  ##
  def get(id), do: Aggregate.get(__MODULE__, id)
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
