defmodule OpsTest do
  use ExUnit.Case
  alias Awsex.Ops

  test "it makes a module" do
    f = File.read!("./service-2.json") |> Ops.parse!
    mod = Ops.module(f)
    {:module, module_name, _desc, fns} = mod

    fn_names = Enum.map(fns, fn({name, _arity}) -> name end)
    arities = Enum.map(fns, fn({_name, arity}) -> arity end)

    assert module_name == Awsex.DataPipeline
    assert fn_names == Ops.operations(f) |> Map.keys |> Enum.map(&String.to_atom/1)
    assert Enum.all?(arities, fn(x) -> x == 3 end)
  end

  test "it gets operations" do
    f = File.read!("./service-2.json") |> Ops.parse!
    assert length(Ops.operations(f) |> Map.keys) > 0

    assert Ops.operations(f) |> Map.keys == Ops.operations(f) |> Map.keys |> Enum.map(&String.downcase/1)

  end

  test "it snake cases" do
    assert Ops.snake_case("ActivatePipeline") == "activate_pipeline"
  end

  test "it reads parses a json file" do
    f = File.read!("./service-2.json")
    assert Ops.parse!(f) |> Map.get("version") == "2.0"
  end
end
