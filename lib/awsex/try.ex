defmodule Awsex.Try do
  def first!(errors, []) do
    {:error, errors}
  end

  def first!(errors, [{mod, fun, args} | mfas]) do
    try do
      res = apply(mod, fun, args)
      {:ok, res}
    rescue
      e -> first!([e | errors], mfas)
    end
  end

  def first!(mfas) do
    first!([], mfas)
  end
end
