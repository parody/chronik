defmodule Chronik.Projection.DumpToFile do
  @moduledoc """
  This module writes all the events received to a local file.

  It servers debugging purposes. Client modules can use this module and start
  it as any projection.
  """
  defmacro __using__([filename: filename]) do
    quote do
      use Chronik.Projection
      alias Chronik.EventRecord

      def init(_opts) do
        File.rm(unquote(filename))
        {unquote(filename), []}
      end

      def handle_event(%EventRecord{domain_event: event}, filename) do
        File.write(filename, "[#{__MODULE__}] #{inspect event}\n", [:append])
        filename
      end
    end
  end
end
