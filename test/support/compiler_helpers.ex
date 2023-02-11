defmodule Dagger.CompilerHelpers do
  alias Dagger.Compiler

  @callback_mod Dagger.Flow
  @callback_imports [defstep: 2, next_step: 1]

  def empty(mod_name, file_name) do
    {:ok, comp} = Compiler.new(mod_name, file_name)
    comp
  end

  def with_preamble(mod_name, file_name) do
    comp = empty(mod_name, file_name)
    Compiler.add_preamble(comp, @callback_mod, @callback_imports)
    comp
  end

  def with_steps(mod_name, file_name, steps) do
    comp = with_preamble(mod_name, file_name)

    Enum.each(steps, fn %{name: name, line: line, args: args, do: block} ->
      Compiler.add_step(comp, @callback_mod, name, line, args, do: block)
    end)

    comp
  end

  def valid(mod_name, file_name, steps \\ []) do
    flow_steps =
      if Enum.empty?(steps) do
        ast =
          quote do
            next_step(finish)
          end

        [
          %{name: :start, line: 4, args: [], do: ast},
          %{name: :finish, line: 10, args: [], do: :ok}
        ]
      else
        [first | _] = steps
        first_name = Map.get(first, :name)

        ast =
          quote do
            next_step(unquote(first_name))
          end

        [
          %{name: :start, line: 4, args: [], do: ast},
          %{name: :finish, line: 10, args: [], do: :ok}
        ]
      end

    flow_steps = flow_steps ++ steps
    with_steps(mod_name, file_name, flow_steps)
  end

  def build_spec({_, _, [{:spec, _, [spec]}]}) do
    [{:spec, spec, :ignored}]
  end
end
