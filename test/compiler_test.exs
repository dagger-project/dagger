defmodule Dagger.CompilerTest do
  use ExUnit.Case, async: true
  alias Dagger.{Compiler, Graph, MissingStepError, StepConfigurationError, NextStepCallError}
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
      generated = Compiler.add_step(comp, MyOtherFlow, :start, 4, [], do: :ok)

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

      Compiler.check_next_step_call!(comp, 10, {:start, 0})
    end

    test "compiler raises when next_step/1 references nonexisting step" do
      comp =
        CompilerHelpers.with_steps(__MODULE__, __ENV__.file, [
          %{name: :start, line: 4, args: [], next: :foo, do: :ok}
        ])

      assert_raise CompileError, fn -> Compiler.check_next_step_call!(comp, 10, {:foo, 2}) end
    end

    test "compiler raises error when missing start step" do
      comp = CompilerHelpers.with_preamble(__MODULE__, __ENV__.file)

      assert_raise MissingStepError,
                   "DAG Elixir.Dagger.CompilerTest is missing the start step",
                   fn -> Compiler.finalize!(comp) end
    end

    test "compiler raises error when missing end step" do
      comp =
        CompilerHelpers.with_steps(__MODULE__, __ENV__.file, [
          %{name: :start, line: 4, args: [], next: :finish, do: :ok}
        ])

      assert_raise MissingStepError,
                   "DAG Elixir.Dagger.CompilerTest is missing the finish step",
                   fn -> Compiler.finalize!(comp) end
    end

    test "compiler raises error when advancing to missing step" do
      ast =
        quote do
          next_step(foo)
        end

      comp =
        CompilerHelpers.with_steps(__MODULE__, __ENV__.file, [
          %{name: :start, line: 4, args: [], do: ast},
          %{name: :finish, line: 8, args: [], do: :ok}
        ])

      assert_raise MissingStepError,
                   "Step start/0 in DAG Elixir.Dagger.CompilerTest advances execution to missing step foo",
                   fn -> Compiler.finalize!(comp) end
    end

    test "compiler raises when step forgets to call next_step" do
      comp =
        CompilerHelpers.valid(__MODULE__, __ENV__.file, [
          %{name: :foo, line: 15, args: [], do: :ok}
        ])

      assert_raise StepConfigurationError, ~r/^Error in step foo/, fn ->
        Compiler.finalize!(comp)
      end
    end

    test "compiler raises when next_step called within if clause" do
      comp = CompilerHelpers.valid(__MODULE__, __ENV__.file)

      ast =
        quote do
          if x > 0 do
            next_step(:finish)
          end
        end

      assert_raise NextStepCallError,
                   ~r/Calling next_step\/1 inside a conditional expression \(if\)/,
                   fn -> Compiler.add_step(comp, MyOtherFlow, :foo, 16, [], do: ast) end
    end

    test "compiler raises when next_step called within else clause" do
      comp = CompilerHelpers.valid(__MODULE__, __ENV__.file)

      ast =
        quote do
          if x > 0 do
            :ok
          else
            next_step(:finish)
          end
        end

      assert_raise NextStepCallError,
                   ~r/Calling next_step\/1 inside a conditional expression \(else\)/,
                   fn -> Compiler.add_step(comp, MyOtherFlow, :foo, 16, [], do: ast) end
    end

    test "compiler raises when next_step called within case expression" do
      comp = CompilerHelpers.valid(__MODULE__, __ENV__.file)

      ast =
        quote do
          case x do
            1 ->
              next_step(:finish)
          end
        end

      assert_raise NextStepCallError,
                   ~r/Calling next_step\/1 inside a conditional expression \(case\)/,
                   fn -> Compiler.add_step(comp, MyOtherFlow, :foo, 16, [], do: ast) end
    end

    test "compiler raises when next_step called within cond expression" do
      comp = CompilerHelpers.valid(__MODULE__, __ENV__.file)

      ast =
        quote do
          cond do
            x > 0 ->
              next_step(:finish)
          end
        end

      assert_raise NextStepCallError,
                   ~r/Calling next_step\/1 inside a conditional expression \(cond\)/,
                   fn -> Compiler.add_step(comp, MyOtherFlow, :foo, 16, [], do: ast) end
    end

    test "compiler raises when next_step called within with expression" do
      comp = CompilerHelpers.valid(__MODULE__, __ENV__.file)

      ast =
        quote do
          with {:ok, x} <- do_something(),
               do: next_step(foo)
        end

      assert_raise NextStepCallError,
                   ~r/Calling next_step\/1 inside a conditional expression \(with\)/,
                   fn -> Compiler.add_step(comp, MyOtherFlow, :foo, 16, [], do: ast) end
    end

    test "compiler generates dag/0 after finalization" do
      file_name = __ENV__.file
      comp = CompilerHelpers.valid(__MODULE__, __ENV__.file)
      generated = Compiler.finalize!(comp)

      assert {:def, _,
              [
                {:dag, [context: Dagger.Compiler], []},
                [
                  do:
                    {:%{}, [],
                     [
                       __struct__: Dagger.Graph,
                       file_name: ^file_name,
                       module: Dagger.CompilerTest,
                       sanitized_name: "dagger-compiler-test",
                       steps:
                         {:%{}, [],
                          [
                            {{Dagger.CompilerTest, :finish},
                             {:%{}, [],
                              [
                                __struct__: Dagger.Graph.Step,
                                arity: 0,
                                fun_name: :finish,
                                inputs: [],
                                line: 10,
                                name: :finish,
                                next: nil,
                                return: :unknown
                              ]}},
                            {{Dagger.CompilerTest, :start},
                             {:%{}, [],
                              [
                                __struct__: Dagger.Graph.Step,
                                arity: 0,
                                fun_name: :start,
                                inputs: [],
                                line: 4,
                                name: :start,
                                next: :finish,
                                return: :unknown
                              ]}}
                          ]}
                     ]}
                ]
              ]} = generated
    end

    test "compiler detects primitive types from step spec" do
      ast =
        quote do
          next_step(finish)
        end

      comp =
        CompilerHelpers.valid(__MODULE__, __ENV__.file, [
          %{name: :foo, args: [:a, :b], line: 6, do: ast}
        ])

      spec =
        CompilerHelpers.build_spec(
          quote do
            @spec foo(integer(), integer()) :: integer()
          end
        )

      Compiler.handle_spec(comp, spec)
      dag = Compiler.get_dag(comp)
      step = Graph.get_step(dag, :foo)
      assert step
      assert step.inputs == [:integer, :integer]
      refute step.return == :unknown
    end

    test "compiler detects external type args from step spec" do
      ast =
        quote do
          next_step(finish)
        end

      comp =
        CompilerHelpers.valid(__MODULE__, __ENV__.file, [
          %{name: :foo, args: [:a, :b], line: 6, do: ast}
        ])

      spec =
        CompilerHelpers.build_spec(
          quote do
            @spec foo(String.t(), integer()) :: integer()
          end
        )

      Compiler.handle_spec(comp, spec)
      dag = Compiler.get_dag(comp)
      step = Graph.get_step(dag, :foo)
      assert step
      assert step.inputs == [:String, :integer]
      assert step.return == :integer
    end

    test "compiler detects external type return from step spec" do
      ast =
        quote do
          next_step(finish)
        end

      comp =
        CompilerHelpers.valid(__MODULE__, __ENV__.file, [
          %{name: :foo, args: [:a, :b], line: 6, do: ast}
        ])

      spec =
        CompilerHelpers.build_spec(
          quote do
            @spec foo(String.t()) :: String.t()
          end
        )

      Compiler.handle_spec(comp, spec)
      dag = Compiler.get_dag(comp)
      step = Graph.get_step(dag, :foo)
      assert step
      assert step.inputs == [:String]
      assert step.return == :String
    end

    test "compiler detects list arg from step spec" do
      ast =
        quote do
          next_step(finish)
        end

      comp =
        CompilerHelpers.valid(__MODULE__, __ENV__.file, [
          %{name: :foo, args: [:a], line: 6, do: ast}
        ])

      spec =
        CompilerHelpers.build_spec(
          quote do
            @spec foo([String.t()]) :: String.t()
          end
        )

      Compiler.handle_spec(comp, spec)
      dag = Compiler.get_dag(comp)
      step = Graph.get_step(dag, :foo)
      assert step
      assert step.inputs == [%{member_type: :String, type: :list}]
      assert step.return == :String
    end

    test "compiler detects typed map arg from step spec" do
      ast =
        quote do
          next_step(finish)
        end

      comp =
        CompilerHelpers.valid(__MODULE__, __ENV__.file, [
          %{name: :foo, args: [:a], line: 6, do: ast}
        ])

      spec =
        CompilerHelpers.build_spec(
          quote do
            @spec foo(%{String.t() => integer()}) :: String.t()
          end
        )

      Compiler.handle_spec(comp, spec)
      dag = Compiler.get_dag(comp)
      step = Graph.get_step(dag, :foo)
      assert step
      assert step.inputs == [%{type: :map, key_type: :String, value_type: :integer}]
      assert step.return == :String
    end

    test "compiler detects map arg with specific keys from step spec" do
      ast =
        quote do
          next_step(finish)
        end

      comp =
        CompilerHelpers.valid(__MODULE__, __ENV__.file, [
          %{name: :foo, args: [:a], line: 6, do: ast}
        ])

      spec =
        CompilerHelpers.build_spec(
          quote do
            @spec foo(%{user: [integer()]}) :: String.t()
          end
        )

      Compiler.handle_spec(comp, spec)
      dag = Compiler.get_dag(comp)
      step = Graph.get_step(dag, :foo)
      assert step
      assert step.inputs == [%{type: :map, key_type: :String, value_type: :integer}]
      assert step.return == :String
    end
  end
end
