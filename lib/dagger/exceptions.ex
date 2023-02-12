defmodule Dagger.GraphNeverFinishesError do
  defexception [:message]

  @impl true
  def exception(module: mod) do
    msg = "DAG #{mod} never advances to finish step"
    %__MODULE__{message: msg}
  end
end

defmodule Dagger.MissingStepError do
  defexception [:message, :module, :step]

  @impl true
  def exception(module: mod, step: missing) do
    msg = "DAG #{mod} is missing the #{missing} step"
    %__MODULE__{message: msg, module: mod, step: missing}
  end

  def exception(module: mod, step: step, missing_step: missing) do
    msg = "Step #{step} in DAG #{mod} advances execution to missing step #{missing}"

    %__MODULE__{message: msg, module: mod, step: missing}
  end
end

defmodule Dagger.NextStepCallError do
  defexception [:message]

  @impl true
  def exception(file: file, expr_type: type) do
    exception(file: file, line: 0, expr_type: type)
  end

  def exception(file: file, line: line, expr_type: type) do
    msg =
      Enum.join(
        [
          "#{file}:#{line}: Calling next_step/1 inside a conditional",
          "expression (#{type}) is not allowed"
        ],
        " "
      )

    %__MODULE__{message: msg}
  end
end

defmodule Dagger.StepConfigurationError do
  defexception [:message]

  @impl true
  def exception(module: mod, step: "finish/0") do
    msg = "The finish step in DAG #{mod} advances execution"
    %__MODULE__{message: msg}
  end

  def exception(module: mod, step: step) do
    msg = "Error in step #{step} in DAG #{mod}"

    hint = "Did you forget to call next_step/1?"

    %__MODULE__{message: Enum.join([msg, hint], "\n")}
  end
end

defmodule Dagger.UnusedStepsError do
  defexception [:message, :module, :steps]

  @impl true
  def exception(module: mod, steps: steps) do
    msg =
      if length(steps) == 1 do
        "Unused step found in DAG #{mod}:"
      else
        "Unused steps foudn in DAG #{mod}:"
      end

    msg = "#{msg} #{Enum.join(steps, ", ")}"
    %__MODULE__{message: msg, module: mod, steps: steps}
  end
end
