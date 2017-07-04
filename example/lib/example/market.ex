defmodule Example.Market do
  @moduledoc """
  Market API
  """

  defstruct [:id, :type, :trading_status, :predictions]

  # API

  def create(id, type) do
    %__MODULE__{
      id: id,
      type: type,
      trading_status: :suspended,
      predictions: []
    }
  end
end
