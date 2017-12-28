defmodule Chronik.Utils do
  @moduledoc "Utility module for debugging"
  if Application.get_env(:chronik, :debug, true) do
    require Logger
    defmacro debug(msg) do
      quote do
        Logger.debug("#{inspect __MODULE__}] #{unquote(msg)}")
      end
    end
  else
    defmacro debug(_msg), do: :ok
  end

  defmacro warn(msg) do
    quote do
      Logger.warn("#{inspect __MODULE__}] #{unquote(msg)}")
    end
  end
end
