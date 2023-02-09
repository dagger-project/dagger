defmodule Dagger.Compiler.Checkers.NoConditionalsChecker do
  defstruct [:prohibited, :in_conditional, :file_name]

  def new(prohibited) do
    %__MODULE__{prohibited: prohibited}
  end
end

alias Dagger.Compiler.Checkers.NoConditionalsChecker

defimpl Dagger.Compiler.Checker, for: NoConditionalsChecker do
  def check!(%NoConditionalsChecker{} = checker, file_name, ast) do
    # Reset in_conditional flag and file_name before checking
    checker = %{checker | in_conditional: false, file_name: file_name}
    ensure_no_conditionals(checker, ast)
  end

  defp ensure_no_conditionals(_checker, []), do: :ok

  defp ensure_no_conditionals(_checker, :ok), do: :ok

  defp ensure_no_conditionals(checker, {:__block__, _, body}) do
    ensure_no_conditionals(checker, body)
  end

  defp ensure_no_conditionals(checker, {:case, _, body}) do
    ensure_no_conditionals(%{checker | in_conditional: true}, body)
  end

  defp ensure_no_conditionals(checker, {:cond, _, body}) do
    ensure_no_conditionals(%{checker | in_conditional: true}, body)
  end

  defp ensure_no_conditionals(checker, {:if, _, body}) do
    ensure_no_conditionals(%{checker | in_conditional: true}, body)
  end

  defp ensure_no_conditionals(checker, {:and, _, rest}) do
    ensure_no_conditionals(checker, rest)
  end

  defp ensure_no_conditionals(checker, {:do, rest}) do
    ensure_no_conditionals(checker, rest)
  end

  defp ensure_no_conditionals(checker, {:else, rest}) do
    ensure_no_conditionals(checker, rest)
  end

  defp ensure_no_conditionals(checker, {:->, _, body}) do
    ensure_no_conditionals(checker, body)
  end

  defp ensure_no_conditionals(checker, [[head] | rest]) do
    if is_tuple(head) or is_list(head) do
      ensure_no_conditionals(checker, head)
    end

    ensure_no_conditionals(checker, rest)
  end

  defp ensure_no_conditionals(checker, ast) when is_tuple(ast) do
    if checker.in_conditional do
      prohibited = checker.prohibited

      case ast do
        {^prohibited, [line: line], _} ->
          raise %CompileError{
            file: checker.file_name,
            line: line,
            description:
              "Calling #{checker.prohibited} inside a conditional expression is not allowed"
          }

        _ ->
          :ok
      end
    else
      :ok
    end
  end

  defp ensure_no_conditionals(checker, [expr | rest]) do
    ensure_no_conditionals(checker, expr)
    ensure_no_conditionals(checker, rest)
  end
end
