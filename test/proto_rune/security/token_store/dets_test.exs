defmodule ProtoRune.Security.TokenStore.DetsTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Security.TokenStore.Dets

  setup do
    path = Path.join(System.tmp_dir!(), "proto_rune_dets_test_#{System.unique_integer([:positive])}.dets")
    on_exit(fn -> File.rm(path) end)

    %{opts: [path: path], path: path}
  end

  describe "put/3 and fetch/2" do
    test "roundtrip a blob", %{opts: opts} do
      assert :ok = Dets.put("did:plc:alice", "encrypted-blob", opts)
      assert {:ok, "encrypted-blob"} = Dets.fetch("did:plc:alice", opts)
    end

    test "overwrites an existing entry", %{opts: opts} do
      assert :ok = Dets.put("did:plc:alice", "old", opts)
      assert :ok = Dets.put("did:plc:alice", "new", opts)
      assert {:ok, "new"} = Dets.fetch("did:plc:alice", opts)
    end

    test "handles ids with characters that are unsafe in file names", %{opts: opts} do
      assert :ok = Dets.put("did:plc:a/b:c?d", "blob", opts)
      assert {:ok, "blob"} = Dets.fetch("did:plc:a/b:c?d", opts)
    end

    test "creates missing parent directories" do
      dir = Path.join(System.tmp_dir!(), "proto_rune_dets_nested_#{System.unique_integer([:positive])}")
      path = Path.join([dir, "nested", "tokens.dets"])
      on_exit(fn -> File.rm_rf(dir) end)

      assert :ok = Dets.put("did:plc:alice", "blob", path: path)
      assert {:ok, "blob"} = Dets.fetch("did:plc:alice", path: path)
    end

    test "restricts the table file to mode 0o600", %{opts: opts, path: path} do
      assert :ok = Dets.put("did:plc:alice", "blob", opts)
      assert {:ok, stat} = File.stat(path)
      assert Bitwise.band(stat.mode, 0o777) == 0o600
    end
  end

  describe "fetch/2" do
    test "returns :not_found for a missing id", %{opts: opts} do
      assert {:error, :not_found} = Dets.fetch("did:plc:missing", opts)
    end
  end

  describe "delete/2" do
    test "removes an existing entry", %{opts: opts} do
      assert :ok = Dets.put("did:plc:alice", "blob", opts)
      assert :ok = Dets.delete("did:plc:alice", opts)
      assert {:error, :not_found} = Dets.fetch("did:plc:alice", opts)
    end

    test "returns :ok for a missing entry", %{opts: opts} do
      assert :ok = Dets.delete("did:plc:missing", opts)
    end
  end
end
