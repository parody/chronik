defmodule Chronik.EventRecord do
  @moduledoc """
  A structure that represents a record of a domain event in the
  `Chronik.Store` or on the `Chronik.PubSub`.
  """

  defstruct [
    # The aggregate that emitted this event.
    :aggregate,
    # Creation timestamp.
    :created_at,
    # Data of the domain event.
    :domain_event,
    # Version of the event.
    :version,
    # Version of the aggregate that generated the event.
    :aggregate_version
  ]

  @type t :: %__MODULE__{
          aggregate: Chronik.Aggregate.t(),
          created_at: non_neg_integer(),
          domain_event: any(),
          version: Chronik.Store.version(),
          aggregate_version: Chronik.Store.version()
        }

  # API

  @doc "Helper function for creating records from domain events"
  @spec create(
          domain_event :: Chronik.domain_event(),
          aggregate :: Chronik.Aggregate.t(),
          version :: Chronik.Store.version(),
          aggregate_version :: Chronik.Store.version()
        ) :: __MODULE__.t()
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
