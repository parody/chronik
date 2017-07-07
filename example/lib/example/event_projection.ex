defmodule Example.EventProjection do
  use Chronik.Projection

  def init do
    %{}
  end

  def next_state(state, event) do
    new_state = update_in(state, [event.event_id], &([event | &1 || []]))
    IO.inspect new_state, label: "#{inspect __MODULE__} new state"
  end
end
