defmodule Chronik do
  @moduledoc """
  Chronik is a lightweight EventSourcing/CQRS micro framework for Elixir.

  Chronik application is composed of four components:
  * The `Chronik.Store` which is an persisted store for domain events.
  Two adapters are provided `Chronik.Store.Adapters.Ecto` and
  `Chronik.Store.Adapters.ETS`.
  * The `Chronik.PubSub` which publishes the domain events generated
  by the `Chronik.Aggregate`. In `Chronik` there is only one topic on the
  PubSub, a stream-all. This provides a global order of the events.
  Chronik provides a Registry based adapter
  `Chronik.PubSub.Adapters.Registry`.
  * The `Chronik.Aggregate` modules which provides the abstraction of an
  aggregate. Aggregates receive and validate commands, based on its current
  state. If the command is accepted a number of domain events are generated
  and stored and published. Finally the aggregate transition to another
  states.
  * The `Chronik.Projection` implements a read model on the `Chronik.PubSub`.
  The domain events are processed in order. Missing events are fetch from
  the `Chronik.Store`.
  """

  @typedoc "The `id` represents an aggregate id. In principle this can be any
  term"
  @type id :: term()

  @typedoc "A `command` in Chronik is a tuple like `{:cmd, arg1 arg2}`"
  @type command :: tuple()

  @typedoc "Domain events can have any form."
  @type domain_event :: term()
end
