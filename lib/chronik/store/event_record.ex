defmodule Chronik.Store.EventRecord do
  @moduledoc """
  EventStore
  """

  defstruct [
    :stream,        # The stream that this event record belongs to
    :event_number,  # The position of the event record in the stream
    :created_at,    # Creation timestamp
    :data           # Data of the event record
  ]

  @type t :: %__MODULE__{
    stream: Chronik.stream,
    event_number: non_neg_integer(),
    created_at: non_neg_integer(),
    data: any()
  }

  # API

  def create(stream, event_number, data) do
    %__MODULE__{
      stream: stream,
      event_number: event_number,
      created_at: System.system_time(),
      data: data
    }
  end
end
