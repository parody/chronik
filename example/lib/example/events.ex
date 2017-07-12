defmodule Example.DomainEvents do
  
  defmodule CartCreated do
    defstruct [
      :id,
    ]
  end

  defmodule ItemsAdded do
    defstruct [
      :id,
      :item_id,
      :quantity
    ]
  end

  defmodule ItemsRemoved do
    defstruct [
      :id,
      :item_id,
      :quantity
    ]
  end
end