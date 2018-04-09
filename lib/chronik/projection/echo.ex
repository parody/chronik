defmodule Chronik.Projection.Echo do
  @moduledoc """
  This module is just an Echo projection to standard output.

  It serves for debugging purposes. Client modules can use this module
  and start it as any projection.
  """

  defmacro __using__(_opts) do
    quote do
      @behaviour Chronik.Projection

      alias Chronik.{EventRecord, Projection}

      def start_link(opts), do: Projection.start_link(__MODULE__, opts)

      def init(_opts), do: {nil, []}

      def handle_event(%EventRecord{domain_event: event}, state) do
        IO.puts("[#{__MODULE__}] #{inspect(event)}")
        state
      end
    end
  end
end
