defmodule Awsex.Ops do
  @moduledoc """
  At compile time: generates modules and functions
  to access the functionality described in a given
  JSON API specification.
  """
  alias Awsex.Auth
  require Poison

  defmacro __before_compile__(_env) do
    quote do
      f = File.read!("./service-2.json") |> Awsex.Ops.parse!
      Awsex.Ops.module(f)
    end
  end

  @spec module(%{String.t => String.t}) :: module()
  def module(desc) do
    metadata = metadata(desc)
    module_name = metadata |> target_prefix |> String.to_atom
    module_contents =
      desc
      |> operations
      |> Enum.map(fn(operation) ->
           to_def(operation, metadata)
         end)
    service_documentation = quote do
      @moduledoc Map.fetch!(unquote(Macro.escape(desc)), "documentation")
    end

    Module.create(
      Module.concat([Awsex, module_name]),
      [service_documentation|module_contents],
      Macro.Env.location(__ENV__)
    )
  end

  @spec to_def({String.t, %{String.t => String.t}}, %{String.t => String.t}) :: any()
  def to_def({fn_name, operation}, meta) do
    doc = Map.fetch!(operation, "documentation")

    quote do
      @doc """
      #{unquote(doc)}
      """
      def unquote(String.to_atom(fn_name))(client, request_params) do
        auth = Auth.main(
          client,
          Map.put_new(
            request_params,
            "action", Macro.camelize(unquote(fn_name))
          ),
          # Maps are not valid quoted expressions and must be escaped,
          # see: http://elixir-lang.org/getting-started/meta/quote-and-unquote.html#escaping
          unquote(Macro.escape(meta))
        )

        response = HTTPoison.post!(
          Map.fetch!(auth, "host"),
          Map.fetch!(auth, "body"),
          Map.fetch!(auth, "headers")
        )

        Map.put(response, :body, Poison.decode!(response.body))
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
  @moduledoc """
  This module provides a separate compilation unit to force the evaluation
  of the macros in Awsex.Ops
  """
  require Awsex.Ops
  @before_compile Awsex.Ops
end
