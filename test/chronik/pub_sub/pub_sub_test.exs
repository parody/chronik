defmodule Chronik.PubSub.Test do
  use ExUnit.Case, async: false

  alias Chronik.EventRecord

  # TODO: Move this macro to a general test module?
  defmacro assert_ok(val) do
    quote do
      assert :ok = unquote(val)
    end
  end

  setup_all do
    {_store, pub_sub} = Chronik.Config.fetch_adapters()
    {:ok, _} = pub_sub.start_link(keys: :duplicate, name: pub_sub)
    {:ok, %{pub_sub: pub_sub}}
  end

  test "subscribe, broadcast and receive events", %{pub_sub: pub_sub} do
    stream = "test_stream1"

    # Check that we can subscribe to a stream
    assert_ok pub_sub.subscribe(stream)

    # Check taht we can broadcast to a stream
    assert_ok pub_sub.broadcast(stream,  [:event1, :event2, :event3])

    # Check that events are received (in order)
    assert_receive :event1
    assert_receive :event2
    assert_receive :event3
  end

  test "filter some events", %{pub_sub: pub_sub} do
    stream = "test_stream2"

    # Subscribe to the stream filtering out :event2
    assert_ok pub_sub.subscribe(stream, &(&1 != :event2))

    pub_sub.broadcast(stream,  [:event1, :event2, :event3])

    # Assert that we receive :event1 and :event3
    assert_receive :event1
    assert_receive :event3
    # and that we DON NOT receive :event2
    refute_receive :event2
  end

  test "unsubscribe and re-subscrive from/to a stream", %{pub_sub: pub_sub} do
    stream = "test_stream3"

    pub_sub.subscribe(stream)
    pub_sub.broadcast(stream,  [:event1])
    
    # Check that we can unsubscribe from the stream
    assert_ok pub_sub.unsubscribe(stream)
    
    # :event2 is broadcasted while we are unsubscried from the stream
    pub_sub.broadcast(stream,  [:event2])

    # We re-subscribe to the stream
    pub_sub.subscribe(stream)

    # :event3 is broadcasted while we ARE subscribed
    pub_sub.broadcast(stream,  [:event3])

    # Check that we receive :event1 and :event3 since we were 
    # subscribed when the events were broadcasted
    assert_receive :event1
    assert_receive :event3

    # Check that we DO NOT receive :event2 since we were unsubscribed
    refute_receive :event2
  end

  test "multiple subscriptions", %{pub_sub: pub_sub} do
    stream4 = "test_stream4"
    stream5 = "test_stream5"
    events4 = [EventRecord.create(stream4, 0, :event1),
               EventRecord.create(stream4, 1, :event2)]
    events5 = [EventRecord.create(stream5, 0, :event3)]

    # Subscribe to two different streams.
    pub_sub.subscribe(stream4)
    pub_sub.subscribe(stream5)

    # Broadcast :event1 and :event2 to stream4 and :event3 to stream5
    pub_sub.broadcast(stream4, events4)
    pub_sub.broadcast(stream5, events5)

    # Check that events do not cross streams.
    refute_receive %EventRecord{stream: ^stream5, data: :event1}
    refute_receive %EventRecord{stream: ^stream5, data: :event2}
    refute_receive %EventRecord{stream: ^stream4, data: :event3}

    # Check the events are received from the correct stream.
    assert_receive %EventRecord{stream: ^stream4, offset: 0, data: :event1}
    assert_receive %EventRecord{stream: ^stream4, offset: 1, data: :event2}
    assert_receive %EventRecord{stream: ^stream5, offset: 0, data: :event3}
  end
end