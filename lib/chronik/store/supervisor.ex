defmodule Chronik.Store.Supervisor do
  @moduledoc false

  use Supervisor

  # API

  def start_link(store, adapter, opts) do
    name = Keyword.get(opts, :name, store)
    Supervisor.start_link(__MODULE__, {store, adapter, opts}, name: name)
  end

  def fetch_config(store, opts) do
    # Stolen from Ecto
    otp_app = Keyword.fetch!(opts, :otp_app)
    config  = Application.get_env(otp_app, store, [])
    adapter = opts[:adapter] || config[:adapter]

    unless adapter, do: raise Chronik.MissingStoreError, opts

    case Code.ensure_loaded?(adapter) do
      true -> {config, adapter}
      false -> raise Chronik.AdapterLoadError, adapter
    end
  end

  # Supervisor callbacks

  def init({store, adapter, opts}) do
    children = [adapter.child_spec(store, opts)]
    supervise(children, strategy: :one_for_one)
  end
end
