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
    {cmd, id_arg, args} =
      case tuple do
        {cmd, id} -> {cmd, id, [id]}
        tuple ->
          args = elem(tuple,2)
          [cmd, id | rest] = args
          {cmd, id , [id | rest]}
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