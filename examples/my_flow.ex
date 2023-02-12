defmodule MyFlow do
  use Dagger.Flow

  defstep start() do
    next_step(foo)
  end

  # Use specs to define input / output types
  # These will be validated during flow execution
  @spec foo(integer(), number()) :: integer()
  defstep foo(a,b) do
    next_step(bar)
    a + b
  end

  @spec bar([float()]) :: [float()]
  defstep bar(dataset) do
    next_step(finish)
    # Automatically parallelized with configurable upper limit
    map(dataset, &train/1)
  end

  defstep finish(), do: :ok

  def train(data) do
    # Machine learning stuff
    IO.puts(data)
  end

end
