defmodule Example.Event do
  @moduledoc """
  Event API
  """

  use Chronik.Aggregate

  alias Example.{Event, Market, Prediction}

  alias Example.DomainEvents.{
    EventCreated,
    EventTradingStatusChanged,
    MarketCreated,
    PredictionCreated,
    OddsUpdated
  }

  defstruct [
    :id,                # event id
    :markets,           # map from market_id -> %Market{}
    :predictions,       # map from pred_id -> %Market{}
    :trading_status     # indicates the trading status of the event
  ]

  # API

  ## Command validators

  def create(nil, event_id) do
    %EventCreated{event_id: event_id}
  end
  def create(_state, event_id) do
    fail("event #{event_id} already exists")
  end

  def add_market(%Event{} = event, market_id, type) do
    case Map.has_key?(event.markets, market_id) do
      true ->
        fail("market #{market_id} already exists")
      false ->
        %MarketCreated{event_id: event.id, market_id: market_id, type: type}
    end
  end

  def add_prediction(%Event{} = event, market_id, pred_id, odds) do
    case Map.has_key?(event.predictions, pred_id) do
      true ->
        fail("prediction #{pred_id} already exists")
      false ->
        %PredictionCreated{market_id: market_id, pred_id: pred_id, odds: odds}
    end
  end

  def set_trading_status(%Event{} = event, trading_status) do
    %EventTradingStatusChanged{event_id: event.id, trading_status: trading_status}
  end
  def set_trading_status(_state, _trading_status) do
    fail("invalid state")
  end

  def update_odds(%Event{} = event, pred_id, odds) do
    case Map.fetch(event.predictions, pred_id) do
      {:ok, pred} ->
        Prediction.update_odds(pred, odds)
      :error ->
        fail("prediction #{pred_id} not found")
    end
  end

  ##
  ## Aggregate callbacks
  ##

  def get_aggregate_id(%Event{id: aggregate_id}) do
    aggregate_id
  end

  def next_state(nil, %EventCreated{event_id: event_id}) do
    %Event{
      id: event_id,
      markets: %{},
      predictions: %{},
      trading_status: :suspended
    }
  end
  def next_state(state, %MarketCreated{} = n) do
    market = Market.create(n.market_id, n.type)
    put_in(state.markets, market.id, market)
  end
  def next_state(state, %PredictionCreated{} = n) do
    prediction = Prediction.create(n.pred_id, n.odds)

    state.predictions
    |> put_in(prediction.id, prediction)
    |> update_in(state.markets[n.market_id].predictions, &[n.pred_id | &1])
  end
  def next_state(state, %EventTradingStatusChanged{} = n) do
    %{state | trading_status: n.trading_status}
  end
  def next_state(state, %OddsUpdated{} = n) do
    update_in(state.predictions[n.pred_id], &Prediction.update_odds(&1, n.odds))
  end

  ## Aggregate command handlers

  def handle_command({:create, event_id}) do
    Event.call(event_id,
      fn state ->
        execute(state, &Event.create(&1, event_id))
      end)
  end
end
