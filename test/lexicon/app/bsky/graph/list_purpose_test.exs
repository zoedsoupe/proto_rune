defmodule Lexicon.App.Bsky.Graph.ListPurposeTest do
  use ExUnit.Case, async: true

  alias Lexicon.App.Bsky.Graph.ListPurpose

  describe "valid?/1" do
    test "validates list purposes" do
      assert ListPurpose.valid?(:modlist)
      assert ListPurpose.valid?(:curatelist)
      assert ListPurpose.valid?(:referencelist)

      refute ListPurpose.valid?(:invalid)
      refute ListPurpose.valid?(nil)
      refute ListPurpose.valid?("modlist")
    end
  end

  describe "from_string/1" do
    test "converts valid strings to atoms" do
      assert {:ok, :modlist} = ListPurpose.from_string("app.bsky.graph.defs#modlist")
      assert {:ok, :curatelist} = ListPurpose.from_string("app.bsky.graph.defs#curatelist")
      assert {:ok, :referencelist} = ListPurpose.from_string("app.bsky.graph.defs#referencelist")
    end

    test "returns error for invalid strings" do
      assert :error = ListPurpose.from_string("invalid")
      assert :error = ListPurpose.from_string(nil)
      assert :error = ListPurpose.from_string("app.bsky.graph.defs#invalid")
    end
  end

  describe "from_string!/1" do
    test "converts valid strings to atoms" do
      assert :modlist = ListPurpose.from_string!("app.bsky.graph.defs#modlist")
      assert :curatelist = ListPurpose.from_string!("app.bsky.graph.defs#curatelist")
      assert :referencelist = ListPurpose.from_string!("app.bsky.graph.defs#referencelist")
    end

    test "raises error for invalid strings" do
      assert_raise ArgumentError, ~r/Invalid list purpose/, fn ->
        ListPurpose.from_string!("invalid")
      end
    end
  end

  describe "to_string/1" do
    test "converts atoms to strings" do
      assert "app.bsky.graph.defs#modlist" = ListPurpose.to_string(:modlist)
      assert "app.bsky.graph.defs#curatelist" = ListPurpose.to_string(:curatelist)
      assert "app.bsky.graph.defs#referencelist" = ListPurpose.to_string(:referencelist)
    end

    test "raises error for invalid atoms" do
      assert_raise ArgumentError, ~r/Invalid list purpose/, fn ->
        ListPurpose.to_string(:invalid)
      end
    end
  end
end
