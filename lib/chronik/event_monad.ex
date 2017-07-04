defmodule Chronik.EventMonad do
  @moduledoc """
  Chronik EventMonad macros and functions
  """

  # API

  @doc ""
  def return(s), do: {s, []}

  @doc ""
  defmacro left ~> right do
    quote do
      case unquote(left) do
        {:error, _m} = err ->
          err
        {s, l} ->
          {ns, nl} = s |> unquote(right)
          {ns, l ++ nl}
      end
    end
  end
end
