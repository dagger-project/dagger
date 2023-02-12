defmodule Dagger.Graph do
  alias Dagger.{GraphNeverFinishesError, StepConfigurationError, MissingStepError}
  alias Dagger.Graph.Step
  defstruct [:module, :file_name, :sanitized_name, :steps]

  def new(module, file_name) do
    {:ok,
     %__MODULE__{
       module: module,
       file_name: file_name,
       sanitized_name: sanitize_module_name(module),
       steps: %{}
     }}
  end

  def step_names(graph), do: {:ok, Map.keys(graph.steps)}

  def get_step(graph, step_name, default \\ nil) do
    key = {graph.module, step_name}
    {:ok, Map.get(graph.steps, key, default)}
  end

  def update_step(graph, step) do
    key = {graph.module, step.fun_name}
    {:ok, %{graph | steps: Map.put(graph.steps, key, step)}}
  end

  def add_step(graph, step) do
    cond do
      step.fun_name == nil ->
        {:error, :no_name}

      step.arity == nil ->
        {:error, :no_arity}

      true ->
        key = {graph.module, step.fun_name}
        {:ok, %{graph | steps: Map.put(graph.steps, key, step)}}
    end
  end

  def has_step?(graph, step_name) do
    key = {graph.module, step_name}
    Map.has_key?(graph.steps, key)
  end

  def validate!(graph) do
    validate_required_steps!(graph)
    validate_step_configuration!(graph)
    validate_graph_linkage!(graph)
  end

  defp validate_graph_linkage!(graph) do
    {:ok, names} = step_names(graph)
    names = names -- [{graph.module, :start}]

    remaining =
      Enum.reduce(Map.values(graph.steps), names, fn step, names ->
        if step.next == nil do
          names
        else
          Enum.filter(names, &(&1 != {graph.module, step.next}))
        end
      end)

    if not Enum.empty?(remaining) do
      if Enum.find(remaining, &(&1 == {graph.module, :finish})) do
        raise GraphNeverFinishesError, module: graph.module
      else
        {:warn, {:unused_steps, remaining}}
      end
    else
      :ok
    end
  end

  defp validate_step_configuration!(graph) do
    Enum.each(Map.values(graph.steps), fn step ->
      if step.fun_name == :finish do
        if step.next != nil do
          raise StepConfigurationError, module: graph.module, step: Step.display_name(step)
        end
      else
        if step.next == nil do
          raise StepConfigurationError, module: graph.module, step: Step.display_name(step)
        end

        if not has_step?(graph, step.next) do
          raise MissingStepError,
            module: graph.module,
            step: Step.display_name(step),
            missing_step: step.next
        end
      end
    end)
  end

  defp validate_required_steps!(graph) do
    if not has_step?(graph, :start) do
      raise MissingStepError, module: graph.module, step: :start
    end

    if not has_step?(graph, :finish) do
      raise MissingStepError, module: graph.module, step: :finish
    end
  end

  defp sanitize_module_name(name) when is_atom(name) do
    Atom.to_string(name)
    |> sanitize_module_name()
  end

  defp sanitize_module_name(name) when is_binary(name) do
    String.replace_leading(name, "Elixir.", "")
    |> String.replace(~r/\./, "")
    |> String.slice(0..30)
    |> hyphenate()
  end

  defp hyphenate(text) do
    limit = String.length(text) - 1

    Enum.map(0..limit, fn i ->
      c = String.at(text, i)

      if c == String.upcase(c) do
        if i > 0 do
          ["-", String.downcase(c)]
        else
          String.downcase(c)
        end
      else
        c
      end
    end)
    |> Enum.join()
  end
end

defimpl Jason.Encoder, for: Dagger.Graph do
  def encode(graph, opts) do
    keys = Map.keys(graph.steps) |> Enum.sort()
    ordered_steps = Enum.map(keys, &Map.get(graph.steps, &1))

    Jason.Encode.keyword(
      [module: graph.module, sanitized_name: graph.sanitized_name, steps: ordered_steps],
      opts
    )
  end
end
