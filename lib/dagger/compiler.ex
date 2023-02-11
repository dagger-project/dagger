defmodule Dagger.Compiler do
  alias Dagger.MissingStepError
  alias Dagger.Graph
  alias Dagger.Graph.Step
  alias Dagger.Compiler.{Checker, Tracker, SpecParser}
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

  def get_dag(comp) do
    Tracker.dag(comp.tracker_pid)
  end

  def add_step(comp, callback_module, name, line, args, do: block) do
    next_step = extract_next_step(comp, block)
    step = Step.new(name, line, length(args), next_step)
    dag = get_dag(comp)
    Tracker.update_dag(comp.tracker_pid, Graph.add_step(dag, step))
    ast = {name, [line: line], args}

    quote do
      def unquote(ast) do
        unquote(callback_module)._spec_hook_()
        unquote(block)
      end
    end
  end

  def check_next_step_call!(comp, line, {fun_name, arity}) do
    dag = get_dag(comp)

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

  def finalize!(comp) do
    dag = get_dag(comp)
    validate!(dag)
    dag = Macro.escape(dag)

    quote do
      def dag(), do: unquote(dag)
    end
  end

  def handle_spec(_comp, []) do
  end

  def handle_spec(comp, spec) do
    dag =
      get_dag(comp)
      |> SpecParser.parse_signature(spec)

    Tracker.update_dag(comp.tracker_pid, dag)
  end

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
