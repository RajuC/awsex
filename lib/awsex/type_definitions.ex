defmodule Awsex.TypeDefinitions do
  @api_spec File.read!("service-2.json") |> Poison.decode!

  defmacro __before_compile__(_env) do
    Enum.each(capitalized_shapes(shapes), &to_module/1)
  end

  def to_module(shape) do
    # map shape types to elixir types
    # create quoted content, struct defintion
    # define module

    {shape_name, _shape_value} = shape
    name = Module.concat([Awsex, prefix, String.to_atom(shape_name)])
    fields = shape_to_types(shape)

    contents = quote do
      defstruct unquote(fields)
    end

    # @type t :: unquote(%__MODULE__{types}) # one day son.
    Module.create(name, contents, Macro.Env.location(__ENV__))
  end

  def make_structs(shapes) do
    Enum.map(shapes, &shape_to_types/1)
  end

  def shape_to_types({_shape_name, shape_value}) do
    case Map.fetch(shape_value, "members") do
      {:ok, members} -> Enum.map(members, &member_to_field/1)
      :error -> [] # noop
    end
  end

  def member_to_field({member_name, _member}) do
    field_name =
      Awsex.HttpMacros.camel_to_snake(member_name)
      |> String.to_atom

    {field_name, nil}
  end

  def structure_shapes(shapes) do
    Enum.filter(shapes, fn {_shape_name, shape_value} ->
      Map.values(shape_value)
      |> Enum.member?("structure")
    end)
  end

  def capitalized_shapes(shapes) do
    Map.take(shapes, capitalized_shape_keys)
  end

  def capitalized_shape_keys do
    Enum.filter(shapes_keys, &is_capitalized?/1)
  end

  # def lowercase_shapes(shapes) do
  #   Map.take(shapes, lowercase_shape_keys(shapes))
  # end

  # def lowercase_shape_keys(shapes) do
  #   Enum.reject(shapes_keys, &is_capitalized?/1)
  # end

  def shapes do
    deep_fetch!(@api_spec, ["shapes"])
  end

  def prefix do
    deep_fetch!(@api_spec, ["metadata", "targetPrefix"])
  end

  def operations do
    deep_fetch!(@api_spec, ["operations"])
  end

  def shapes_keys, do: Map.keys(shapes)

  # def primitive_shapes(shapes) do
  #   shape_types(shapes, primitive_types)
  # end

  def composite_shapes(shapes) do
    shape_types(shapes, composite_types)
  end

  def shape_types(shapes, types) do
    Enum.filter(shapes, fn {_shape_name, shape_value} ->
      Enum.into(Map.values(shape_value), HashSet.new)
      |> Set.intersection(types)
      |> (&(Set.size(&1) > 0)).()
    end)
  end

  # def types, do: Set.union(primitive_types, composite_types)

  # def primitive_types do
  #   [
  #     "string",
  #     "boolean",
  #     "timestamp",
  #     "integer"
  #   ] |> Enum.into(HashSet.new)
  # end

  def composite_types do
    [
      "list",
      "structure",
      "map"
    ] |> Enum.into(HashSet.new)
  end

  # PEW
  def deep_fetch!(result, []), do: result
  def deep_fetch!(map, [key|remaining_keys]) do
    Map.fetch!(map, key) |> deep_fetch!(remaining_keys)
  end

  def is_capitalized?(str) do
    upper_first = String.first(str) |> String.upcase
    String.starts_with?(str, upper_first)
  end
end
