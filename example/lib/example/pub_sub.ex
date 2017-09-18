defmodule Example.PubSub do
  @moduledoc false
  use Chronik.PubSub, otp_app: :example

  def child_spec(opts) do
    %{
    id: __MODULE__,
    start: {__MODULE__, :start_link, [opts]},
    type: :supervisor
    }
  end

  defoverridable child_spec: 1
end
