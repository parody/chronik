defmodule Chronik.PubSub.Adapters.RegistryTest do
  use ExUnit.Case, async: true

  alias Chronik.EventRecord

  @adapter Chronik.PubSub.Adapters.Registry

  # TODO: Move this macro to a general test module?
  defmacro assert_ok(val) do
    quote do
      assert :ok = unquote(val)
    end
  end

  setup_all do
    # FIXME: Is this the correct way to start the adapter?
    {:ok, _} = @adapter.start_link(keys: :duplicate, name: @adapter)
    {:ok, %{adapter: @adapter}}
  end

  test "subscribe, broadcast and receive events", %{adapter: adapter} do
    stream = "test_stream1"
    assert_ok adapter.subscribe(stream)
    assert_ok adapter.broadcast(stream,  [:event1, :event2, :event3])

    assert_receive :event1
    assert_receive :event2
    assert_receive :event3
  end

  test "filter some events", %{adapter: adapter} do
    stream = "test_stream2"
    assert_ok adapter.subscribe(stream, &(&1 != :event2))
    assert_ok adapter.broadcast(stream,  [:event1, :event2, :event3])

    assert_receive :event1
    assert_receive :event3
    refute_receive :event2
  end

  test "unsubscribe and re-subscrive from/to a stream", %{adapter: adapter} do
    stream = "test_stream3"
    assert_ok adapter.subscribe(stream)
    assert_ok adapter.broadcast(stream,  [:event1])
    assert_ok adapter.unsubscribe(stream)
    assert_ok adapter.broadcast(stream,  [:event2])
    assert_ok adapter.subscribe(stream)
    assert_ok adapter.broadcast(stream,  [:event3])

    assert_receive :event1
    assert_receive :event3
    refute_receive :event2
  end

  test "multiple subscriptions", %{adapter: adapter} do
    stream4 = "test_stream4"
    stream5 = "test_stream5"

    assert_ok adapter.subscribe(stream4)
    assert_ok adapter.subscribe(stream5)
    assert_ok adapter.broadcast(stream4,
      [EventRecord.create(stream4, 0, :event1),
       EventRecord.create(stream4, 1, :event2)])
    assert_ok adapter.broadcast(stream5,
      [EventRecord.create(stream5, 0, :event3)])

    refute_receive %EventRecord{stream: ^stream5, data: :event1}
    refute_receive %EventRecord{stream: ^stream5, data: :event2}
    refute_receive %EventRecord{stream: ^stream4, data: :event3}
    assert_receive %EventRecord{stream: ^stream4, offset: 0, data: :event1}
    assert_receive %EventRecord{stream: ^stream4, offset: 1, data: :event2}
    assert_receive %EventRecord{stream: ^stream5, offset: 0, data: :event3}
  end
end