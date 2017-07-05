defmodule Chronik.Store.Adapters.ETSTest do
  use ExUnit.Case

  @adapter Chronik.Store.Adapters.ETS

  setup_all do
    @adapter.init(nil)
    {:ok, %{adapter: @adapter}}
  end

  test "insert events", %{adapter: adapter} do
    assert {:ok, 1, [_, _]} = adapter.append("test_stream1", [:event1, :event2], version: :any)
    assert {:error, "wrong expected version"} = adapter.append("test_stream1", [:event1], version: :no_stream)
    assert {:ok, _, _} = adapter.append("test_stream1", [:event3], version: 1)
    assert {:error, "wrong expected version"} = adapter.append("test_stream1", [:event4], version: 1)
  end

  test "retrieve events", %{adapter: adapter} do
    assert {:ok, last = 2, [_, _, _]} = adapter.append("test_stream2", [:event1, :event2, :event3], version: :no_stream)
    assert {:ok, ^last, []} = adapter.fetch("test_stream2", last)
    assert {:ok, ^last, [%{data: :event3}]} = adapter.fetch("test_stream2", 1)

    data_list =
      "test_stream2"
      |> adapter.fetch
      |> elem(2)
      |> Enum.map(&(&1.data))

    assert [:event1, :event2, :event3] = data_list

    data_list =
   	  "test_stream2"
   	  |> adapter.fetch(0)
   	  |> elem(2)
   	  |> Enum.map(&(&1.data))

    assert [:event2, :event3] = data_list
  end

  test "singleton domain event store", %{adapter: adapter} do
    {error, _} = adapter.init(nil)
    assert error != :ok
  end
end
