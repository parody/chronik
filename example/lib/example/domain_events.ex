defmodule Example.DomainEvents do
  @moduledoc "DomainEvents"

  defmodule EventCreated do
    @moduledoc false
    defstruct [
      :created_at,
      :event_id
    ]
  end

  defmodule MarketCreated do
    @moduledoc false
    defstruct [
      :created_at,
      :event_id,
      :market_id,
      :type
    ]
  end

  defmodule EventTradingStatusChanged do
    @moduledoc false
    defstruct [
      :created_at,
      :event_id,
      :trading_status,
    ]
  end

  defmodule MarketTradingStatusChanged do
    @moduledoc false
    defstruct [
      :created_at,
      :event_id,
      :market_id,
      :trading_status,
    ]
  end

  defmodule PredictionCreated do
    @moduledoc false
    defstruct [
      :created_at,
      :market_id,
      :pred_id,
      :odds
    ]
  end

  defmodule PredictionTradingStatusChanged do
    @moduledoc false
    defstruct [
      :created_at,
      :event_id,
      :market_id,
      :prediction_id,
      :trading_status,
    ]
  end

  defmodule OddsUpdated do
    @moduledoc false
    defstruct [
      :created_at,
      :pred_id,
      :odds
    ]
  end
end
