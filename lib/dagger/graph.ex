defmodule Dagger.Graph do
  alias Dagger.{StepConfigurationError, MissingStepError}
  alias Dagger.Graph.Step
  defstruct [:module, :file_name, :sanitized_name, :steps]

  def new(module, file_name) do
    %__MODULE__{
      module: module,
      file_name: file_name,
      sanitized_name: sanitize_module_name(module),
      steps: %{}
    }
  end

  def step_names(graph), do: Map.keys(graph.steps)

  def get_step(graph, step_name, default \\ nil) do
    key = {graph.module, step_name}
    Map.get(graph.steps, key, default)
  end

  def update_step(graph, step) do
    key = {graph.module, step.fun_name}
    %{graph | steps: Map.put(graph.steps, key, step)}
  end

  def add_step(graph, step) do
    key = {graph.module, step.fun_name}
    %{graph | steps: Map.put(graph.steps, key, step)}
  end

  def has_step?(graph, step_name) do
    key = {graph.module, step_name}
    Map.has_key?(graph.steps, key)
  end

  def validate!(graph) do
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

  defp sanitize_module_name(name) when is_atom(name) do
    Atom.to_string(name)
    |> sanitize_module_name()
  end

  defp sanitize_module_name(name) when is_binary(name) do
    String.replace_leading(name, "Elixir.", "")
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
    steps = Enum.map(graph.steps, fn {_, step} -> step end)

    Jason.Encode.map(
      %{module: graph.module, sanitized_name: graph.sanitized_name, steps: steps},
      opts
    )
  end
end
