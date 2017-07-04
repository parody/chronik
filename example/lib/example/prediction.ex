defmodule Example.Prediction do
  @moduledoc """
  Prediction API
  """

  alias Example.Prediction
  alias Example.DomainEvents.OddsUpdated

  defstruct [:id, :odds, :trading_status]

  # API

  def create(id, odds) do
    %Prediction{
      id: id,
      odds: odds,
      trading_status: :suspended
    }
  end

  def update_odds(%Prediction{trading_status: ts} = pred, odds) when ts in ~w(open suspended)a do
    %OddsUpdated{pred_id: pred.id, odds: odds}
  end
  def update_odds(_pred, _odds) do
    {:error, "cannot update odds: invalid trading status"}
  end
end
