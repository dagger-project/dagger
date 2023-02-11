defmodule Dagger.Flow do
  alias Dagger.Compiler

  defmacro __using__(_) do
    Module.register_attribute(__CALLER__.module, :dagger_compiler,
      accumulate: false,
      persist: false
    )

    {:ok, comp} = Compiler.new(__CALLER__.module, __CALLER__.file)
    Module.put_attribute(__CALLER__.module, :dagger_compiler, comp)
    Compiler.add_preamble(comp, __MODULE__, defstep: 2, next_step: 1, map: 2)
  end

  defmacro defstep({name, line, args}, do_block) do
    comp = Module.get_attribute(__CALLER__.module, :dagger_compiler)
    Compiler.add_step(comp, __MODULE__, name, line, args, do_block)
  end

  defmacro next_step(_name) do
    comp = Module.get_attribute(__CALLER__.module, :dagger_compiler)
    Compiler.check_next_step_call!(comp, __CALLER__.line, __CALLER__.function)
  end

  def map(_enum, _callback) do
    :ok
  end

  defmacro _spec_hook_() do
    comp = Module.get_attribute(__CALLER__.module, :dagger_compiler)
    spec = Module.get_attribute(__CALLER__.module, :spec)
    Compiler.handle_spec(comp, spec)
  end

  defmacro __before_compile__(_env) do
    comp = Module.get_attribute(__CALLER__.module, :dagger_compiler)
    Compiler.finalize!(comp)
  end
end
