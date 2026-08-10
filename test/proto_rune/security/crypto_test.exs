defmodule ProtoRune.Security.CryptoTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Security.Crypto

  describe "generate_key/0" do
    test "returns a random 32-byte key" do
      key = Crypto.generate_key()

      assert byte_size(key) == 32
      assert key != Crypto.generate_key()
    end
  end

  describe "encode_key/1 and decode_key/1" do
    test "roundtrip a generated key" do
      key = Crypto.generate_key()

      assert encoded = Crypto.encode_key(key)
      assert is_binary(encoded)
      assert {:ok, ^key} = Crypto.decode_key(encoded)
    end

    test "decode_key/1 rejects keys with the wrong size" do
      assert {:error, :invalid_key_size} = Crypto.decode_key(Base.encode64("too short"))
    end

    test "decode_key/1 rejects invalid Base64" do
      assert {:error, :invalid_key_encoding} = Crypto.decode_key("not base64!!!")
    end
  end

  describe "encrypt/2 and decrypt/2" do
    setup do
      %{key: Crypto.generate_key()}
    end

    test "roundtrip a plaintext payload", %{key: key} do
      assert {:ok, blob} = Crypto.encrypt("hello tokens", key)
      assert is_binary(blob)
      assert {:ok, "hello tokens"} = Crypto.decrypt(blob, key)
    end

    test "encrypts empty binaries", %{key: key} do
      assert {:ok, blob} = Crypto.encrypt("", key)
      assert {:ok, ""} = Crypto.decrypt(blob, key)
    end

    test "produces different blobs for the same plaintext", %{key: key} do
      {:ok, blob_a} = Crypto.encrypt("same", key)
      {:ok, blob_b} = Crypto.encrypt("same", key)

      assert blob_a != blob_b
    end

    test "fails to decrypt with a different key", %{key: key} do
      {:ok, blob} = Crypto.encrypt("secret", key)

      assert {:error, :decrypt_failed} = Crypto.decrypt(blob, Crypto.generate_key())
    end

    test "fails to decrypt a tampered blob", %{key: key} do
      {:ok, blob} = Crypto.encrypt("secret", key)
      {:ok, data} = Base.decode64(blob)
      tampered = Base.encode64(data <> "x")

      assert {:error, :decrypt_failed} = Crypto.decrypt(tampered, key)
    end

    test "rejects a blob that is not valid Base64", %{key: key} do
      assert {:error, :invalid_blob} = Crypto.decrypt("not base64!!!", key)
    end

    test "rejects a blob without the expected layout", %{key: key} do
      assert {:error, :invalid_blob} = Crypto.decrypt(Base.encode64("short"), key)
    end

    test "rejects invalid keys" do
      assert {:error, :invalid_key} = Crypto.encrypt("data", "short")
      assert {:error, :invalid_key} = Crypto.decrypt("whatever", "short")
    end
  end
end
