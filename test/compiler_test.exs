defmodule Dagger.CompilerTest do
  use ExUnit.Case, async: true
  alias Dagger.Compiler
  alias Dagger.CompilerHelpers

  describe "codegen" do
    test "compiler adds correct preamble" do
      comp = CompilerHelpers.empty(__MODULE__, __ENV__.file)
      generated = Compiler.add_preamble(comp, Dagger.Flow, defstep: 2)

      assert {:__block__, [],
              [
                {:require, [context: Dagger.Compiler], [Dagger.Compiler]},
                {:@, [context: Dagger.Compiler, imports: [{1, Kernel}]],
                 [
                   {:before_compile, [context: Dagger.Compiler],
                    [{:__aliases__, [alias: false], [:Dagger, :Flow]}]}
                 ]},
                {:import, [context: Dagger.Compiler], [Dagger.Flow, [only: [defstep: 2]]]}
              ]} == generated
    end

    test "compiler builds correct AST for step" do
      comp = CompilerHelpers.with_preamble(__MODULE__, __ENV__.file)
      generated = Compiler.add_step(comp, MyOtherFlow, :start, [line: 4], [], do: :ok)

      assert {:def, [{:context, Dagger.Compiler}, {:imports, [{1, Kernel}, {2, Kernel}]}],
              [
                {:start, [line: 4], []},
                [do: {:__block__, [], [{{:., [], [MyOtherFlow, :_spec_hook_]}, [], []}, :ok]}]
              ]} == generated
    end

    test "compiler allows next_step/1 referencing an existing step" do
      comp =
        CompilerHelpers.with_steps(__MODULE__, __ENV__.file, [
          %{name: :start, line: 4, args: [], do: :ok, next: nil}
        ])

      Compiler.check_next_step_call!(comp, [line: 10], {:start, 0})
    end

    test "compiler raises when next_step/1 references nonexisting step" do
      comp =
        CompilerHelpers.with_steps(__MODULE__, __ENV__.file, [
          %{name: :start, line: 4, args: [], next: :foo, do: :ok}
        ])

      assert Compiler.check_next_step_call!(comp, [line: 10], {:foo, 2})
    end
  end
end
