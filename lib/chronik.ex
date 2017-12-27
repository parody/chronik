defmodule Chronik do
  @moduledoc """
  A lightweight EventSourcing/CQRS micro framework for Elixir.

  `Chronik` is composed of four components:

  * The `Chronik.Store` which is an persisted data store for domain
    events. Two adapters are provided:

      - `Chronik.Store.Adapters.Ecto`
      - `Chronik.Store.Adapters.ETS`

  * The `Chronik.PubSub` which publishes the domain events generated
    by `Chronik.Aggregate`. In `Chronik` there is only one topic on
    the PubSub: a stream-all. This provides a global order of the
    events. Chronik provides a `Registry` based adapter
    `Chronik.PubSub.Adapters.Registry`.

  * The `Chronik.Aggregate` modules which provides the abstraction of
    an aggregate. Aggregates receive and validate commands based on
    its current state. If the command is accepted, a number of domain
    events are generated, stored and published. Finally, the aggregate
    transitions to the next desirable state.

  * The `Chronik.Projection` implements a read model on the
    `Chronik.PubSub`. The domain events are processed in
    order. Missing events are fetch from `Chronik.Store`.

  Debuggin can be turned off by placing
  ```
  config :chronik, :debug, false
  ```
  in a config script.
  """

  @typedoc "The `id` represents an aggregate identifier"
  @type id :: term()

  @typedoc """
  A `command` in Chronik is a 3 element tuple with the following
  format: `{:cmd, arg1 arg2}`
  """
  @type command :: tuple()

  @typedoc "Domain events can have any shape"
  @type domain_event :: any()
end
