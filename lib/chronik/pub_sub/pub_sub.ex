defmodule Chronik.PubSub do
  @moduledoc """
  PubSub adapter contract.

  In Chronik there is only one feed (all). This means that subscribers
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

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      @doc false
      def start_link(opts \\ []) do
        Chronik.PubSub.Supervisor.start_link(__MODULE__, @adapter, opts)
      end

      defoverridable child_spec: 1
    end
  end

  @typedoc "The result status of all operations on the pub_sub"
  @type result_status :: :ok | {:error, String.t}

  @doc """
  Subscribes the caller to the PubSub.

  Multiple subscriptions to the PubSub are allowed. The
  subscriber will receive the events multiple times.

  The accepted options are:
  * `consistency`: `:eventual` (default) or `:strict`.
  """
  @callback subscribe(opts :: Keyword.t) :: result_status

  @doc """
  Unsubscribes the caller from the PubSub. No further events are
  received from the PubSub. Note: events could
  still be on the mailbox.
  """
  @callback unsubscribe() :: result_status

  @doc """
  Broadcasts an enumeration of `records` to all the subscribers.
  """
  @callback broadcast(records :: [Chronik.EventRecord]) :: result_status
end
