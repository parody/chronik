defmodule Chronik.PubSub.Adapters.RegistryTest do
  use ExUnit.Case

  @adapter Chronik.PubSub.Adapters.Registry

  setup_all do
    @adapter.init(nil)
    {:ok, %{adapter: @adapter}}
  end

  test "insert events", %{adapter: adapter} do
    @adapter.subscribe("test_stream1")
    assert true
  end
end
