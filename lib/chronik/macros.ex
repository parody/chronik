defmodule Chronik.Macros do
  @moduledoc """
  This module provides a number of utility macros used
  along Chronik.
  """

  @doc """
  The `defevent` macro is used to define domain events that go into
  the Store and the PubSub.
  For example:
  ```
  defevent(CounterIncremented, [:id, :increment])
  ```
  """
  defmacro defevent(event_name, event_args) do
    quote do
      defmodule unquote(event_name) do
        defstruct unquote(event_args)
      end
    end
  end

  @doc """
  The `defcommand` an utility macro used to define the `handle_command`
  callback.

  For example the function:
  ```
  def handle_call({:create, id}) do
    __MODULE__.call(id,
    fn state ->
      state
      |> execute(&create_validator(&1, id))
    end)
  end
  ```
  can be define with this macro as:
  ```
  defcommand create(id) do
    fn state ->
      state
      |> execute(&create_validator(&1, id))
    end)
  end
  ```

  This macro also defines a `create(id)` function which calls the `handle_call`
  so the user can call `__MODULE__.create(1234)`.
  """
  defmacro defcommand(name_args, [do: code]) do
    cmd = elem(name_args, 0)
    arg_list =
      name_args
      |> elem(2)
      |> List.insert_at(0, cmd)

    [_cmd, id | rest] = arg_list
    tuple =
      case length(arg_list) do
        2 -> List.to_tuple(arg_list)
        _ -> {:{}, [], arg_list}
      end
    api_args = [id | rest]
    quote do
      # API Call
      def unquote(cmd)(unquote_splicing(api_args)) do
        handle_command(unquote(tuple))
      end

      # Chronik callback
      def handle_command(unquote(tuple)) do
        Logger.debug(fn -> "Executing command #{inspect unquote(tuple)}" end)
        __MODULE__.call(unquote(id),
        unquote(code)
        )
      end
    end
  end
end
