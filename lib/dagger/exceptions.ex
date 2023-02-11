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

defmodule Dagger.StepConfigurationError do
  defexception [:message]

  @impl true
  def exception(module: mod, step: step) do
    msg = "Error in step #{step} in DAG #{mod}"

    hint = "Did you forget to call next_step/1?"

    %__MODULE__{message: Enum.join([msg, hint], "\n")}
  end
end
