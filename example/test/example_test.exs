defmodule ExampleTest do
  use ExUnit.Case

  alias Example.Cart

  test "Double creating a cart" do
    cart_id = "1"
    assert {:ok, 0} = Cart.handle_command({:create, cart_id})
    assert {:error, _} = Cart.handle_command({:create, cart_id})
  end

  test "Removing from an empty cart" do
    cart_id = "2"
    item_id = "1"
    Cart.handle_command({:create, cart_id})
    assert {:error, _} = Cart.handle_command({:remove_items, cart_id, item_id, 1})
  end

  test "Adding items to a cart" do
    cart_id = "3"
    item_id = "1"
    Cart.handle_command({:create, cart_id})
    assert {:ok, 1} = Cart.handle_command({:add_items, cart_id, item_id, 1})
  end

  test "Adding and removing items to a cart. Using a projection" do
    cart_id = "4"

    # Create cart
    Cart.handle_command({:create, cart_id})

    # Add three items 1 and then remove one item
    Cart.handle_command({:add_items, cart_id, "1", 3})
    Cart.handle_command({:remove_items, cart_id, "1", 1})

    # Add five items 2
    Cart.handle_command({:add_items, cart_id, "2", 5})

    # Add ten items 3
    Cart.handle_command({:add_items, cart_id, "3", 10})

    # Get current projection state
    {_, %Cart{id: ^cart_id, items: items}} = Cart.get(cart_id)

    # At this point the cart has two items 1, five items 2 and ten items 3
    assert %{"1" => 2, "2" => 5, "3" => 10} = items
  end
end
