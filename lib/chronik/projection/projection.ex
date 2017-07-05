defmodule Chronik.Projection do
  @moduledoc """
  Chronik projection
  """
  @callback next_state(Chronik.state, Chronik.event) :: Chronik.state

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Chronik.Projection
      unquote(projection(opts))
      unquote(consumer(opts))
      unquote(supervisor(opts))
    end
  end

  defp supervisor(opts) do
    quote do
      @doc false
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      defoverridable child_spec: 1

      def start_link(_opts \\ []) do
        child = Module.concat([__MODULE__, Worker])
        Chronik.Projection.Supervisor.start_link([child], [name: child])
      end
    end
  end

  defp projection(opts) do
    quote do
      @worker_module unquote(Module.concat([__MODULE__, Worker]))

      defmodule @worker_module do
        use GenServer

        # API
        def start_link(_opts) do
          GenServer.start_link(@worker_module, nil, name: @worker_module)
        end

        # GenServer callbacks
        def init(_) do
          {:ok, nil}
        end

        def handle_info({:next_state, event}, state) do
          {:noreply, next_state(state, event)}
        end
      end
    end
  end

  defp consumer(opts) do
    quote do
      @consumer_module unquote(Module.concat([__MODULE__, Consumer]))

      defmodule @consumer_module do
        use GenServer

        # API

        def start_link([_store, _pubsub] = args) do
          GenServer.start_link(@consumer_module, args, name: @consumer_module)
        end

        # GenServer callbacks

        def init([_store, _pubsub]) do
          {:ok, nil}
        end

        def handle_info(_msg, state) do
          {:noreply, state}
        end
      end

    end
  end
end
