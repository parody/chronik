defmodule Chronik.Projection.Echo do
  use Chronik.Projection

  def init(), do: nil

  def next_state(_state, _event) do
#    IO.puts "[__MODULE__] #{inspect event}"
    nil
  end
end