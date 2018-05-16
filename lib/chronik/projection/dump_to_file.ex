defmodule Chronik.Projection.DumpToFile do
  @moduledoc """
  This module writes all the events received to a local file.

  It serves for debugging purposes. Client modules can use this module
  and start it as any projection.
  """

  defmacro __using__(filename: filename) do
    quote do
      @behaviour Chronik.Projection

      alias Chronik.{EventRecord, Projection}

      def start_link(opts), do: Projection.start_link(__MODULE__, opts)

      def init(_opts) do
        File.rm(unquote(filename))
        {unquote(filename), []}
      end

      def handle_event(%EventRecord{domain_event: event}, filename) do
        :ok = File.write(filename, "[#{__MODULE__}] #{inspect(event)}\n", [:append])
        filename
      end
    end
  end
end
