defmodule Chronik.EventRecord do
  @moduledoc """
  A structure that represents a record of a domain event in 
  the Store or on the PubSub.
  """

  defstruct [
    :stream,        # The stream that this event record belongs to
    :offset,        # The position of the event record in the stream
    :created_at,    # Creation timestamp
    :data,          # Data of the event record
    :version        # Version of the event record
  ]

  @type t :: %__MODULE__{
    stream: Chronik.stream,
    offset: non_neg_integer(),
    created_at: non_neg_integer(),
    data: any()
  }

  # API
  @doc """
  Helper funciton to create records from domain events. 

  Returns a record.
  """
  def create(stream, offset, data, version) do
    %__MODULE__{
      stream: stream,
      offset: offset,
      created_at: System.system_time(),
      data: data,
      version: version
    }
  end
end
