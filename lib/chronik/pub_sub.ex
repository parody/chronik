defmodule Chronik.PubSub do
  @moduledoc """
  `Chronik.PubSub` adapter contract and API.

  In `Chronik` there is only one feed (all). This means that subscribers
  see a total ordering of events.
  """

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Chronik.PubSub

      alias Chronik.Config

      {_cfg, adapter} = Config.fetch_config(__MODULE__, opts)

      @adapter adapter

      defdelegate subscribe(opts \\ []), to: @adapter
      defdelegate unsubscribe(), to: @adapter
      defdelegate broadcast(events), to: @adapter
      defdelegate start_link(opts), to: @adapter
    end
  end

  @typedoc "The result status of all operations on the `Chronik.PubSub`"
  @type result_status :: :ok | {:error, String.t()}

  @doc """
  Subscribes the caller to the PubSub.

  Multiple subscriptions to the PubSub are allowed. The
  subscriber will receive the events multiple times.

  The accepted options are:

    - `consistency`: `:eventual` (default) or `:strict`
  """
  @callback subscribe(opts :: Keyword.t()) :: result_status()

  @doc """
  Unsubscribes the caller from the PubSub. No further events are
  received from the PubSub.

  **note**: events could still be on the subscribers' mailbox.
  """
  @callback unsubscribe() :: result_status()

  @doc """
  Broadcasts an enumeration of `records` to all the subscribers.
  """
  @callback broadcast(records :: [Chronik.EventRecord]) :: result_status()

  # API

  def start_link(opts \\ []) do
    {_store, pub_sub} = Chronik.Config.fetch_adapters()
    pub_sub.start_link(opts)
  end
end
