defmodule Dagger.Graph.Step do
  @derive {Jason.Encoder, only: [:line, :arity, :fun_name, :inputs, :name, :next, :return]}
  defstruct [:line, :arity, :name, :fun_name, :inputs, :return, :next]

  def new(fun_name, line, arity, next_step) do
    %__MODULE__{
      line: line,
      arity: arity,
      name: fun_name,
      fun_name: fun_name,
      inputs: [],
      return: :unknown,
      next: next_step
    }
  end

  def display_name(step) do
    "#{step.fun_name}/#{step.arity}"
  end

  def next(step) do
    step.next
  end

  def update_inputs(step, inputs), do: %{step | inputs: inputs}

  def update_return(step, return), do: %{step | return: return}
end
