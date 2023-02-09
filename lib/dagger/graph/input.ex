defmodule Dagger.Graph.Input do
  @derive {Jason.Encoder, only: [:type]}
  defstruct [:type]
end
