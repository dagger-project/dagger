defmodule Dagger.Compiler.SpecParser do
  alias Dagger.Graph

  def parse_signature(dag, [{:spec, {:"::", _, [{fun_name, _, inputs}, return]}, _} | _]) do
    {:ok, step} = Graph.get_step(dag, fun_name)
    inputs = Enum.map(inputs, &parse_type(dag.module, &1))
    return = parse_type(dag.module, return)
    Graph.update_step(dag, %{step | inputs: inputs, return: return})
  end

  defp parse_type(module, {:t, _, _}), do: module
  defp parse_type(_module, {{:., _, [{:__aliases__, _, [type]}, :t]}, _, _}), do: type

  defp parse_type(
         module,
         {:%{}, _,
          [
            {key_type, value_type}
          ]}
       ) do
    parsed_key_type =
      if is_atom(key_type) do
        %{type: :required, name: key_type}
      else
        parse_type(module, key_type)
      end

    %{
      type: :map,
      key_type: parsed_key_type,
      value_type: parse_type(module, value_type)
    }
  end

  defp parse_type(_module, {type, _, _}) when is_atom(type), do: type

  defp parse_type(module, [type]), do: %{type: :list, member_type: parse_type(module, type)}
end
