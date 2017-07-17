defmodule CommandMacro do
  @doc """
  This modules defines a helper macro to define the 
  handle_command function.

  It takes a tuple as
  `{:create, id}` 
  and defines the funcion
  `def handle_command({:create, id}) do
    Cart.call(id,
    fn state ->
      execute(state, &Cart.create(&1, id))
    end)
  end`
  """
  defmacro command(tuple) do
    cmd = 
      case tuple_size(tuple) do
        2 -> elem(tuple, 0)
        _ -> tuple |> elem(2) |> hd
      end

    id_arg = 
      case tuple_size(tuple) do
        2 -> elem(tuple, 1)
        _ -> tuple |> elem(2) |> tl |> hd
      end

    args = 
      case tuple_size(tuple) do
        2 -> [elem(tuple, 1)]
        _ -> tuple |> elem(2) |> tl
      end

    quote do
      def handle_command(unquote(tuple)) do
        __MODULE__.call(unquote(id_arg),
          fn state ->
            execute(state,
              &__MODULE__.unquote(cmd)(&1, unquote_splicing(args)))
          end)
      end
    end
  end
end