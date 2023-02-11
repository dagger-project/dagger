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

    Enum.each(steps, fn %{name: name, line: line, args: args, do: _} ->
      Compiler.add_step(comp, @callback_mod, name, [line: line], args, do: :ok)
    end)

    comp
  end
end
