defmodule Chronik.Config do
  @moduledoc "Misc utilities and helpers used by `Chronik`"

  @doc """
  Returns the adapter configuration for a given `module`
  """
  @spec fetch_config(mod :: module(), opts :: Keyword.t()) :: {term(), atom()} | no_return()
  def fetch_config(mod, opts) do
    # Stolen from Ecto
    otp_app = Keyword.fetch!(opts, :otp_app)
    config = Application.get_env(otp_app, mod, [])
    adapter = opts[:adapter] || config[:adapter]

    unless adapter, do: raise(Chronik.MissingAdapterError, opts)

    case Code.ensure_loaded?(adapter) do
      true -> {config, adapter}
      false -> raise Chronik.AdapterLoadError, adapter
    end
  end

  @doc "Return an configuration value for a given `module`"
  @spec get_config(mod :: module(), key :: atom(), default :: term()) :: term()
  def get_config(module, key, default) do
    :chronik
    |> Application.get_env(module, [])
    |> Keyword.get(key, default)
  end

  @doc """
  This function returns the configuration for the `chronik`
  application. The values can be changed in the configuration
  environment.
  """
  @spec fetch_adapters :: {atom(), atom()} | no_return()
  def fetch_adapters do
    config = Application.get_env(:chronik, :adapters)
    pub_sub = Keyword.fetch!(config, :pub_sub)
    store = Keyword.fetch!(config, :store)

    {store, pub_sub}
  end
end
