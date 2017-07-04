defmodule Chronik.MissingStoreError do
  defexception [:message]

  def exception(opts) do
    msg = "missing event store adapter. This happens " <>
          "when there is no default adapter configured " <>
          "that implements the event store behaviour.\n" <>
          "options: #{inspect opts}"
    %__MODULE__{message: msg}
  end
end

defmodule Chronik.AdapterLoadError do
  defexception [:message]

  def exception(adapter) do
    msg = "error loading #{inspect adapter}"
    %__MODULE__{message: msg}
  end
end
