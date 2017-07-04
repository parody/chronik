defmodule Chronik.Projection do
  @moduledoc """
  Chronik projection
  """

  @callback next_state(Chronik.state, Chronik.event) :: Chronik.state

  defmacro __using__(_opts) do
    quote do
      use GenServer

      alias Chronik.{PubSub, Store}

      @behaviour Chronik.Projection

      # API

      def start_link(projection_id) do
        GenServer.start_link(__MODULE__, projection_id, name: via(projection_id))
      end

      # GenServer callbacks

      def init(projection_id) do
        # TODO: here we must load all the streams consumed by the projection.
        # Where do we get the streams consumed by the projection from?
        # Idea: the projections must be defined and persisted elsewhere.
        # The definition must include a list of streams (and maybe the all keyword?).
        # This definition can be an initial snapshot?
        {:ok, nil}
      end

      # Internal functions

      defp via(projection_id) do
        {:via, Registry, {Chronik.ProjectionRegistry, projection_id}}
      end
    end
  end
end
