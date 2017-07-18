defmodule Example.Application do
  @moduledoc false

  use Application

  alias Example.DomainEvents.CartCreated
  alias Example.Projection.{CartState, CartsCreated}
  alias Example.{Store, PubSub}

  @public_topics %{
    CartCreated => "CartsCreated"
  }

  @specific_topic {{Example.Cart, "4"}, :all}

  def start(_type, _args) do
    children = [
      {Store, [public_topics: @public_topics, record_version: "2"]},
      {PubSub, []},
      {CartState, [@specific_topic]},
      {CartsCreated, [{"CartsCreated", :all}]}
    ]

    opts = [strategy: :one_for_one, name: Example.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
