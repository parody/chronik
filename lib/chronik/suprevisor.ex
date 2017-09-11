defmodule Chronik.Supervisor do
  @moduledoc "This module is a Supervisor used for the Store and for the PubSub"
  defmacro __using__(_opts) do
    quote do

      use Supervisor

      # API

      def start_link(module, adapter, opts) do
        name = Keyword.get(opts, :name, module)
        Supervisor.start_link(__MODULE__, {module, adapter, opts}, name: name)
      end

      # Supervisor callbacks

      def init({module, adapter, opts}) do
        Supervisor.init([
          {adapter, [module, opts]}
        ], strategy: :one_for_one)
      end
    end
  end
end
