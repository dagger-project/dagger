defmodule Dagger.UnusedStepsTest do
  use ExUnit.Case, async: false
  alias Dagger.{UnusedStepsError, CompilerHelpers, Compiler}

  describe "detect unused steps" do
    test "compiler raises error when unused steps are detected" do
      ast =
        quote do
          next_step(finish)
        end

      unused_ast =
        quote do
          next_step(finish)
        end

      comp =
        CompilerHelpers.valid(__MODULE__, __ENV__.file, [
          %{name: :foo, args: [:a], line: 6, do: ast},
          %{name: :bar, args: [], line: 10, do: unused_ast}
        ])

      Application.put_env(:dagger, :warnings_as_errors, true)

      assert_raise UnusedStepsError, "Unused step found in DAG #{__MODULE__}: bar", fn ->
        Compiler.finalize!(comp)
      end

      Application.put_env(:dagger, :warnings_as_errors, false)
    end

    test "compiler displays warning when unused steps are detected" do
      Application.put_env(:dagger, :warnings_as_errors, false)

      ast =
        quote do
          next_step(finish)
        end

      unused_ast =
        quote do
          next_step(finish)
        end

      comp =
        CompilerHelpers.valid(__MODULE__, __ENV__.file, [
          %{name: :foo, args: [:a], line: 6, do: ast},
          %{name: :bar, args: [], line: 10, do: unused_ast}
        ])

      output = fn _device, message ->
        Process.send(self(), :output_triggered, [])
        assert "WARN: Unused step found in DAG Elixir.Dagger.UnusedStepsTest: bar" == message
      end

      assert Compiler.finalize!(comp, output)
      assert_receive :output_triggered, 100, "Unused step did not trigger console warning"
    end
  end
end
