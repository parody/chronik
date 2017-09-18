defmodule ExampleTest do
  use ExUnit.Case

  alias Example.Cart

  test "Double creating a cart" do
    cart_id = "1"

    # Create a cart.
    assert :ok = Cart.create(cart_id)

    # Check that we cannot re-create the cart.
    assert {:error, _} = Cart.create(cart_id)
  end

  test "Removing from an empty cart" do
    cart_id = "2"
    item_id = "1"

    # Create the cart.
    Cart.create(cart_id)

    # The remove_items command fails on an empty cart.
    assert {:error, _} = Cart.remove_items(cart_id, item_id, 1)
  end

  test "Adding items to a cart" do
    cart_id = "3"
    item_id = "1"

    # Create the cart.
    Cart.create(cart_id)

    # Add an item to the cart.
    assert :ok = Cart.add_items(cart_id, item_id, 1)
  end

  test "Adding and removing items to a cart. Using a projection" do
    cart_id = "4"

    # Create cart
    Cart.create(cart_id)

    # Add three items 1 and then remove one item.
    Cart.add_items(cart_id, "1", 3)
    Cart.remove_items(cart_id, "1", 1)

    # Add five items 2
    Cart.add_items(cart_id, "2", 5)

    # Add ten items 3
    Cart.add_items(cart_id, "3", 10)

    # Get current projection state
    %Cart{id: ^cart_id, items: items} = Cart.state(cart_id)

    # At this point the cart has two items 1, five items 2 and ten items 3
    assert %{"1" => 2, "2" => 5, "3" => 10} = items
  end
end
