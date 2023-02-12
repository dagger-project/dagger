defmodule Dagger.Fixtures do
  def load!(name) do
    File.read!(Path.join(["test", "fixtures", name]))
  end
end
