defmodule Dagger.GraphTest do
  use ExUnit.Case, async: true
  alias Dagger.StepConfigurationError
  alias Dagger.MissingStepError
  alias Dagger.Graph
  alias Dagger.Graph.Step
  alias Dagger.Fixtures

  @mod_name MyOtherFlow
  @file_name "lib/my_other_flow.ex"

  setup_all do
    {:ok, dag} = Graph.new(@mod_name, @file_name)
    %{dag: dag}
  end

  describe "creating and updating graphs" do
    test "add valid step to graph", %{dag: dag} do
      step = Step.new(:start, 4, 0, nil)
      {:ok, dag} = Graph.add_step(dag, step)
      assert {:ok, [{@mod_name, :start}]} == Graph.step_names(dag)
      {:ok, fetched} = Graph.get_step(dag, :start)
      assert step == fetched
    end

    test "add step w/missing name fails", %{dag: dag} do
      step = Step.new(nil, 4, 0, nil)
      assert {:error, :no_name} == Graph.add_step(dag, step)
    end

    test "add step w/missing arity fails", %{dag: dag} do
      step = Step.new(:start, 4, nil, nil)
      assert {:error, :no_arity} == Graph.add_step(dag, step)
    end
  end

  describe "graph validation" do
    test "successful validation", %{dag: dag} do
      {:ok, dag} = Graph.add_step(dag, Step.new(:start, 4, 0, :finish))
      {:ok, dag} = Graph.add_step(dag, Step.new(:finish, 8, 0, nil))
      assert Graph.validate!(dag)
    end

    test "missing start step", %{dag: dag} do
      {:ok, dag} = Graph.add_step(dag, Step.new(:finish, 8, 0, nil))
      expected = "DAG #{@mod_name} is missing the start step"
      assert_raise MissingStepError, expected, fn -> Graph.validate!(dag) end
    end

    test "missing finish step", %{dag: dag} do
      {:ok, dag} = Graph.add_step(dag, Step.new(:start, 4, 0, :finish))
      expected = "DAG #{@mod_name} is missing the finish step"
      assert_raise MissingStepError, expected, fn -> Graph.validate!(dag) end
    end

    test "advances to missing step", %{dag: dag} do
      {:ok, dag} = Graph.add_step(dag, Step.new(:start, 4, 0, :foo))
      {:ok, dag} = Graph.add_step(dag, Step.new(:finish, 8, 0, nil))
      expected = "Step start/0 in DAG #{@mod_name} advances execution to missing step foo"
      assert_raise MissingStepError, expected, fn -> Graph.validate!(dag) end
    end

    test "finish advances execution", %{dag: dag} do
      {:ok, dag} = Graph.add_step(dag, Step.new(:start, 4, 0, :finish))
      {:ok, dag} = Graph.add_step(dag, Step.new(:finish, 8, 0, :foo))

      assert_raise StepConfigurationError,
                   "The finish step in DAG Elixir.MyOtherFlow advances execution",
                   fn -> Graph.validate!(dag) end
    end

    test "unused steps generate warning", %{dag: dag} do
      {:ok, dag} = Graph.add_step(dag, Step.new(:start, 4, 0, :finish))
      {:ok, dag} = Graph.add_step(dag, Step.new(:finish, 8, 0, nil))
      {:ok, dag} = Graph.add_step(dag, Step.new(:foo, 12, 0, :finish))
      assert {:warn, {:unused_steps, [{@mod_name, :foo}]}} == Graph.validate!(dag)
    end
  end

  describe "serialize DAG to JSON" do
    test "encode DAG", %{dag: dag} do
      {:ok, dag} = Graph.add_step(dag, Step.new(:start, 4, 0, :finish))
      {:ok, dag} = Graph.add_step(dag, Step.new(:finish, 8, 0, nil))
      assert Fixtures.load!("basic_dag.json") == Jason.encode!(dag, pretty: true)
    end
  end
end
