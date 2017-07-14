defmodule Chronik.Projection.Echo do
  @moduledoc """
  This module is just an Echo projection to standard output.

  It servers debugging purposes. Client modules can use this module and start
  it as any projection.
  """
  defmacro __using__(_opts) do
    quote do
      use Chronik.Projection

      def init(), do: nil

      def next_state(_state, event) do
        IO.puts "[#{__MODULE__}] #{inspect event}"
      end
    end
  end
end
