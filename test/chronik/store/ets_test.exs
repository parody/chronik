defmodule Chronik.Store.Adapters.ETSTest do
  use ExUnit.Case

  @adapter Chronik.Store.Adapters.ETS

  setup_all do
    @adapter.init()
    {:ok, %{adapter: @adapter}}
  end

  test "insert events", %{adapter: adapter} do
    assert adapter.append("test_stream1", [:event1, :event2]) == :ok
    assert adapter.append("test_stream1", [:event1], version: :no_stream) == {:error, "wrong expected version"}
    assert adapter.append("test_stream1", [:event3], version: 1) == :ok
    assert adapter.append("test_stream1", [:event4], version: 1) == {:error, "wrong expected version"}
  end

  test "retrieve events", %{adapter: adapter} do
    adapter.append("test_stream2", [:event1, :event2, :event3])
    [event] = adapter.fetch("test_stream2", 2)
    assert :event3 = event.data

    data_list =
      "test_stream2"
      |> adapter.fetch()
      |> Enum.map(&(&1.data))

    assert data_list == [:event1, :event2, :event3]

    data_list =
      "test_stream2"
      |> adapter.fetch(1)
      |> Enum.map(&(&1.data))

    assert data_list == [:event2, :event3]
  end

  test "singleton domain event store", %{adapter: adapter} do
    assert {:error, _} = adapter.init()
  end
end
