defmodule Awsex.Ops do
  alias Awsex.Auth
  require Poison

  defmacro __before_compile__(_env) do
    quote do
      f = File.read!("./service-2.json") |> Awsex.Ops.parse!
      Awsex.Ops.module(f)
    end
  end

  def module(desc) do
    module_name = desc |> metadata |> target_prefix |> String.to_atom
    module_contents = operations(desc) |> Enum.map(&to_def/1)

    Module.create(
      Module.concat([Awsex, module_name]),
      module_contents,
      Macro.Env.location(__ENV__)
    )
  end

  def to_def({fn_name, operation}) do
    quote do
      def unquote(String.to_atom(fn_name))(client, input, options \\ []) do
        auth = Auth.main(
          Map.put_new(
            input,
            "Action", Macro.camelize(unquote(fn_name))
          ),
          "us-east-1",
          "datapipeline"
        )

        IO.inspect(auth)

        HTTPoison.post!(
          # "https://datapipeline.us-east-1.amazonaws.com",
          Map.get(auth, "host"),
          Map.get(auth, "body"),
          Map.get(auth, "headers")
        )
      end
    end
  end

  def operations(desc) do
    Map.fetch!(desc, "operations")
    |> Enum.map(fn({k,v}) -> {snake_case(k), v} end)
    |> Enum.into(%{})
  end

  def http_method(op) do
    Map.fetch!(op, "http") |> Map.fetch!("method")
  end

  def target_prefix(desc) do
    Map.fetch!(desc, "targetPrefix")
  end

  def metadata(desc) do
    Map.fetch!(desc, "metadata")
  end

  def snake_case(str), do: Macro.underscore(str)

  def parse!(file), do: Poison.decode!(file)
end

defmodule Awsex.Ops.Real do
  require Awsex.Ops
  @before_compile Awsex.Ops
end
