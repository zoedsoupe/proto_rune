defmodule ProtoRune.XRPC.PaginateTest do
  use ExUnit.Case, async: true

  alias ProtoRune.XRPC

  test "walks pages through the cursor until it runs out" do
    pages = %{
      nil => {:ok, %{feed: [1, 2], cursor: "p2"}},
      "p2" => {:ok, %{feed: [3], cursor: "p3"}},
      "p3" => {:ok, %{feed: [4]}}
    }

    fetch = fn params -> Map.fetch!(pages, Map.get(params, :cursor)) end

    assert fetch |> XRPC.paginate(%{}, :feed) |> Enum.to_list() == [1, 2, 3, 4]
  end

  test "halts on an empty page even with a cursor" do
    fetch = fn _params -> {:ok, %{feed: [], cursor: "more"}} end

    assert fetch |> XRPC.paginate(%{}, :feed) |> Enum.to_list() == []
  end

  test "emits the error as the final element and halts" do
    pages = %{
      nil => {:ok, %{notifications: [:a], cursor: "p2"}},
      "p2" => {:error, :boom}
    }

    fetch = fn params -> Map.fetch!(pages, Map.get(params, :cursor)) end

    assert fetch |> XRPC.paginate(%{}, :notifications) |> Enum.to_list() == [:a, {:error, :boom}]
  end
end
