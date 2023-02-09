defmodule Dagger.Compiler do
  alias Dagger.MissingStepError
  alias Dagger.Graph
  alias Dagger.Graph.Step
  alias Dagger.Compiler.{Checker, Tracker}
  alias Dagger.Compiler.Checkers.NoConditionalsChecker

  defstruct [:tracker_pid, :file_name, :flow_mod]

  def new(flow_mod, file_name) do
    case Tracker.start(Graph.new(flow_mod, file_name)) do
      {:ok, pid} ->
        {:ok, %__MODULE__{tracker_pid: pid, flow_mod: flow_mod, file_name: file_name}}

      error ->
        error
    end
  end

  def add_preamble(_comp, callback_module, imports) do
    quote do
      require unquote(__MODULE__)
      @before_compile Dagger.Flow
      import unquote(callback_module), only: unquote(imports)
    end
  end

  def add_step(comp, callback_module, name, [line: line_num] = line, args, do: block) do
    next_step = extract_next_step(comp, block)
    step = Step.new(name, line_num, length(args), next_step)
    dag = Tracker.dag(comp.tracker_pid)
    Tracker.update_dag(comp.tracker_pid, Graph.add_step(dag, step))
    ast = {name, line, args}

    quote do
      def unquote(ast) do
        unquote(callback_module)._spec_hook_()
        unquote(block)
      end
    end
  end

  def check_next_step_call!(comp, line, {fun_name, arity}) do
    dag = Tracker.dag(comp.tracker_pid)

    if not Graph.has_step?(dag, fun_name) do
      raise %CompileError{
        file: comp.file_name,
        line: line,
        description:
          "next_step/1 called from #{Atom.to_string(fun_name)}/#{arity} which is not a defined step"
      }
    end

    quote do
    end
  end

  def finalize(comp) do
    dag = Tracker.dag(comp.tracker_pid)
    validate!(dag)
    dag = Macro.escape(dag)

    quote do
      def dag(), do: unquote(dag)
    end
  end

  def handle_spec(_comp, []) do
  end

  def handle_spec(comp, spec) do
    {:spec, {:"::", _, [{fun_name, _, inputs}, return]}, _} = hd(spec)
    dag = Tracker.dag(comp.tracker_pid)
    step = Graph.get_step(dag, fun_name)
    inputs = Enum.map(inputs, &parse_type/1)
    step = %{step | inputs: inputs, return: parse_type(return)}
    Tracker.update_dag(comp.tracker_pid, Graph.update_step(dag, step))
  end

  defp parse_type({type, _, _}), do: type

  defp parse_type([{type, _, _}]), do: %{type: :list, member_type: type}

  defp extract_next_step(comp, block) do
    checker = NoConditionalsChecker.new(:next_step)
    Checker.check!(checker, comp.file_name, block)

    {_, next_step} =
      Macro.postwalk(block, nil, fn
        {:next_step, _meta, [{name, _, _}]} = node, _ ->
          {node, name}

        other, next ->
          {other, next}
      end)

    next_step
  end

  defp validate!(dag) do
    if not Graph.has_step?(dag, :start) do
      raise MissingStepError, module: dag.module, step: :start
    end

    if not Graph.has_step?(dag, :finish) do
      raise MissingStepError, module: dag.module, step: :finish
    end

    Graph.validate!(dag)
  end
end
