defmodule Chronik.Projection.Echo do
  @moduledoc """
  This module is just an Echo projection to standard output.

  It servers debugging purposes. Client modules can use this module and start
  it as any projection.
  """
  defmacro __using__(_opts) do
    quote do
      use Chronik.Projection
      alias Chronik.EventRecord

      def init(_opts), do: {nil, []}

      def handle_event(%EventRecord{domain_event: event}, state) do
        IO.puts "[#{__MODULE__}] #{inspect event}"
        state
      end
    end
  end
end
