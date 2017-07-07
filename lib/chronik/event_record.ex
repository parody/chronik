defmodule Chronik.EventRecord do
  @moduledoc """
  A structure that represents a domain event
  """

  defstruct [
    :stream,        # The stream that this event record belongs to
    :offset,        # The position of the event record in the stream
    :created_at,    # Creation timestamp
    :data           # Data of the event record
  ]

  @type t :: %__MODULE__{
    stream: Chronik.stream,
    offset: non_neg_integer(),
    created_at: non_neg_integer(),
    data: any()
  }

  # API

  def create(stream, offset, data) do
    %__MODULE__{
      stream: stream,
      offset: offset,
      created_at: System.system_time(),
      data: data
    }
  end
end
