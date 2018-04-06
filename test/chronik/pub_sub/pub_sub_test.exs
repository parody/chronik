defmodule Chronik.PubSub.Test do
  use ExUnit.Case, async: false

  # TODO: Move this macro to a general test module?
  defmacro assert_ok(val) do
    quote do
      assert :ok = unquote(val)
    end
  end

  setup_all do
    {_store, pub_sub} = Chronik.Config.fetch_adapters()
    {:ok, %{pub_sub: pub_sub}}
  end

  test "subscribe, broadcast and receive events", %{pub_sub: pub_sub} do
    # Check that we can subscribe to the PubSub
    assert_ok(pub_sub.subscribe())

    # Check that we can broadcast to the PubSub
    assert_ok(pub_sub.broadcast([:event1, :event2, :event3]))

    # Check that events are received (in order)
    assert_receive :event1
    assert_receive :event2
    assert_receive :event3
  end

  test "unsubscribe and re-subscrive from/to the PubSub", %{pub_sub: pub_sub} do
    pub_sub.subscribe()
    pub_sub.broadcast([:event1])

    # Check that we can unsubscribe from the PubSub
    assert_ok(pub_sub.unsubscribe())

    # :event2 is broadcasted while we are unsubscried from the PubSub
    pub_sub.broadcast([:event2])

    # We re-subscribe to the PubSub
    pub_sub.subscribe()

    # :event3 is broadcasted while we ARE subscribed
    pub_sub.broadcast([:event3])

    # Check that we receive :event1 and :event3 since we were
    # subscribed when the events were broadcasted
    assert_receive :event1
    assert_receive :event3

    # Check that we DO NOT receive :event2 since we were unsubscribed
    refute_receive :event2
  end
end
