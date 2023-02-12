defmodule Dagger.Compiler.Tracker do
  use Agent

  def start(graph) do
    Agent.start(fn -> %{dag: graph} end, [])
  end

  def dag(pid) do
    Agent.get(pid, fn state -> Map.get(state, :dag) end)
  end

  def update_dag(pid, dag) do
    Agent.update(pid, fn state -> Map.put(state, :dag, dag) end)
  end
end
