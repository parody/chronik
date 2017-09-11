defmodule Chronik.Config do
  @moduledoc "Misc utils"

  @doc "`fetch_config` returns the configuration for a given module."
  @spec fetch_config(mod :: atom(), opts :: Keyword.t)
    :: {term(), atom()} | no_return()
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

  @doc """
  `Chronik` can be configured to use different adapters for the
  `Store` and the `PubSub`. This function returns the configuration
  for the application. They can be changed in the `config/config.ex` file.
  """
  @spec fetch_adapters() :: {atom(), atom()} | no_return
  def fetch_adapters do
    config = Application.get_env(:chronik, :adapters)
    pub_sub = Keyword.fetch!(config, :pub_sub)
    store  = Keyword.fetch!(config, :store)

    {store, pub_sub}
  end
end
