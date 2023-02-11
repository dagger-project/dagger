defmodule Dagger.MissingStepError do
  defexception [:message]

  @impl true
  def exception(module: mod, step: missing) do
    msg = "DAG #{mod} is missing the #{missing} step"
    %__MODULE__{message: msg}
  end

  def exception(module: mod, step: step, missing_step: missing) do
    msg = "Step #{step} in DAG #{mod} advances execution to missing step #{missing}"

    %__MODULE__{message: msg}
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
  def exception(module: mod, step: step) do
    msg = "Error in step #{step} in DAG #{mod}"

    hint = "Did you forget to call next_step/1?"

    %__MODULE__{message: Enum.join([msg, hint], "\n")}
  end
end
