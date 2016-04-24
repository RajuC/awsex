defmodule TryTest do
  use ExUnit.Case
  require Awsex.Try
  alias Awsex.Try

  defmodule TestModule do
    def f1() do
      raise "f1 doesn't work!"
    end

    def f2() do
      raise "f2 still doesn't work"
    end

    def f3() do
      "f3 works!"
    end

    def f4() do
      "f4 also works!"
    end
  end

  test "try!" do
    assert Try.first!(
      [
        {TryTest.TestModule, :f1, []},
        {TryTest.TestModule, :f2, []}
      ]
    ) == {
      :error,
      [
        %RuntimeError{message: "f2 still doesn't work"},
        %RuntimeError{message: "f1 doesn't work!"}
      ]
    }

    assert Try.first!(
      [
        {TryTest.TestModule, :f1, []},
        {TryTest.TestModule, :f2, []},
        {TryTest.TestModule, :f3, []}
      ]
    ) == {:ok, "f3 works!"}

    assert Try.first!(
      [
        {TryTest.TestModule, :f3, []},
        {TryTest.TestModule, :f1, []},
        {TryTest.TestModule, :f2, []},
        {TryTest.TestModule, :f4, []}
      ]
    ) == {:ok, "f3 works!"}
  end
end
