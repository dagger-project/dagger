defprotocol Dagger.Compiler.Checker do
  @type t :: any()

  @spec check!(t(), String.t(), Code.Fragment.t()) :: :ok | no_return()
  def check!(checker, file_name, ast)
end
