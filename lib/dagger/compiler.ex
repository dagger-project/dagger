defmodule Dagger.Compiler do
  alias Dagger.UnusedStepsError
  alias Dagger.Graph
  alias Dagger.Graph.Step
  alias Dagger.Compiler.{Checker, Tracker, SpecParser}
  alias Dagger.Compiler.Checkers.NoConditionalsChecker

  defstruct [:tracker_pid, :file_name, :flow_mod]

  def new(flow_mod, file_name) do
    {:ok, dag} = Graph.new(flow_mod, file_name)

    case Tracker.start(dag) do
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

  def add_step(comp, callback_module, name, [line: line_num] = line, args, do: block) do
    next_step = extract_next_step(comp, block)
    step = Step.new(name, line_num, length(args), next_step)
    dag = get_dag(comp)
    {:ok, dag} = Graph.add_step(dag, step)
    Tracker.update_dag(comp.tracker_pid, dag)
    ast = {name, line, args}

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

  def finalize!(comp, output \\ &IO.puts/2) do
    dag = get_dag(comp)
    result = validate!(dag)

    case result do
      :ok ->
        :ok

      {:warn, {:unused_steps, names}} ->
        names = Enum.map(names, fn {_, name} -> name end)

        case Application.get_env(:dagger, :warnings_as_errors, false) do
          true ->
            raise UnusedStepsError, module: dag.module, steps: names

          false ->
            message =
              if length(names) == 1 do
                "Unused step found in DAG #{dag.module}:"
              else
                "Unused steps found in DAG #{dag.module}:"
              end

            message = "#{message} #{Enum.join(names, ", ")}"
            output.(:stderr, "WARN: #{message}")

          :none ->
            :ok
        end
    end

    escaped = Macro.escape(dag)

    quote do
      def dag(), do: unquote(escaped)
    end
  end

  def handle_spec(_comp, []) do
  end

  def handle_spec(comp, spec) do
    {:ok, dag} =
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

        {:next_step, _meta, [name]} = node, _ ->
          {node, name}

        other, next ->
          {other, next}
      end)

    next_step
  end

  defp validate!(dag), do: Graph.validate!(dag)
end
