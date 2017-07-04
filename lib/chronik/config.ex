defmodule Chronik.Config do
  @moduledoc "Misc utils"

  @doc ""
  @spec fetch_config(atom, Keyword.t) :: {term, atom} | no_return
  def fetch_config(mod, opts) do
    # Stolen from Ecto
    otp_app = Keyword.fetch!(opts, :otp_app)
    config  = Application.get_env(otp_app, mod, [])
    adapter = opts[:adapter] || config[:adapter]

    unless adapter, do: raise Chronik.MissingAdapterError, opts

    case Code.ensure_loaded?(adapter) do
      true -> {config, adapter}
      false -> raise Chronik.AdapterLoadError, adapter
    end
  end

  @doc ""
  @spec fetch_adapters() :: {atom, atom} | no_return
  def fetch_adapters do
    config = Application.get_env(:chronik, :adapters)
    pubsub = Keyword.fetch!(config, :pubsub)
    store  = Keyword.fetch!(config, :store)

    {store, pubsub}
  end
end
