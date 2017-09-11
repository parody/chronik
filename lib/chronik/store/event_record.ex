defmodule Chronik.EventRecord do
  @moduledoc """
  A structure that represents a record of a domain event in
  the Store or on the PubSub.
  """

  defstruct [
    :aggregate,         # The aggregate that emitted this event.
    :created_at,        # Creation timestamp.
    :domain_event,      # Data of the domain event.
    :version,           # Version of the event.
    :aggregate_version, # Version of the aggregate that generated the event.
  ]

  @type t :: %__MODULE__{
    aggregate: any(),
    created_at: non_neg_integer(),
    domain_event: any(),
    version: Chronik.Store.version,
    aggregate_version: Chronik.Store.version
  }

  # API
  @doc """
  Helper funciton to create records from domain events.

  Returns a record.
  """
  # @spec create(domain_event :: Chronik.domain_event,
  #   aggregate :: Chronik.Aggregate, version :: Chronik.Store.version,
  #   aggregate_version :: Chronik.Store.version) :: __MODULE__.t
  def create(domain_event, aggregate, version, aggregate_version) do
    %__MODULE__{
      created_at: System.system_time(:seconds),
      domain_event: domain_event,
      aggregate: aggregate,
      version: version,
      aggregate_version: aggregate_version
    }
  end
end
