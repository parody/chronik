defmodule Chronik do
  @moduledoc """
  Documentation for Chronik.
  """

  @type state   :: term()
  @type event   :: term()
  @type command :: term()

  @typedoc "The type of possible streams"
  @type stream :: term()

  @typedoc "This is a boolean predicate that is used for filtering events in the bus"
  @type predicate :: fun((term() -> boolean()))

  @typedoc "The result status of all operations on the pub_sub"
  @type result_status :: :ok | {:error, String.t}
end
