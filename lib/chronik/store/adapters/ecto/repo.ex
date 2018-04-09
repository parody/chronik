defmodule Chronik.Store.Adapters.Ecto.ChronikRepo do
  @moduledoc false

  use Ecto.Repo, otp_app: :chronik

  alias Confex.Resolver

  def init(_type, config) do
    {:ok, config} = Resolver.resolve(config)

    unless config[:url] do
      raise "Set url config for #{__MODULE__}!"
    end

    {:ok, config}
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end
end
