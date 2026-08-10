defmodule ProtoRune.Security.Crypto do
  @moduledoc """
  Authenticated encryption utilities for session tokens at rest.

  Uses AES-256-GCM from `:crypto` (OTP standard library, no extra
  dependencies). Ciphertexts are versioned, authenticated, and
  Base64-encoded so they can be stored as plain text by any
  `ProtoRune.Security.TokenStore` backend.

  Keys are 32-byte binaries. Generate one with `generate_key/0` and keep
  it outside the token storage itself (environment variable, secret
  manager, etc). `encode_key/1` and `decode_key/1` convert keys to and
  from Base64 for exactly that purpose.
  """

  @key_size 32
  @iv_size 12
  @tag_size 16
  @version 1
  @aad "proto_rune.security.v1"

  @typedoc "A 32-byte AES-256 key."
  @type key :: <<_::256>>

  @doc """
  Generates a random 32-byte encryption key.

  ## Examples

      key = Crypto.generate_key()
      byte_size(key)
      #=> 32
  """
  @spec generate_key() :: key()
  def generate_key, do: :crypto.strong_rand_bytes(@key_size)

  @doc """
  Encodes a key as Base64 for storage in environment variables or config.
  """
  @spec encode_key(key()) :: String.t()
  def encode_key(key) when is_binary(key) and byte_size(key) == @key_size do
    Base.encode64(key)
  end

  @doc """
  Decodes a Base64-encoded key produced by `encode_key/1`.

  Returns `{:error, :invalid_key_size}` when the decoded key is not 32
  bytes and `{:error, :invalid_key_encoding}` when the input is not
  valid Base64.
  """
  @spec decode_key(String.t()) :: {:ok, key()} | {:error, :invalid_key_size | :invalid_key_encoding}
  def decode_key(encoded) when is_binary(encoded) do
    case Base.decode64(encoded) do
      {:ok, <<_::binary-size(@key_size)>> = key} -> {:ok, key}
      {:ok, _other} -> {:error, :invalid_key_size}
      :error -> {:error, :invalid_key_encoding}
    end
  end

  @doc """
  Encrypts a binary payload with AES-256-GCM.

  Returns a Base64-encoded blob containing the format version, the
  random IV, the authentication tag, and the ciphertext.

  ## Examples

      {:ok, blob} = Crypto.encrypt("secret", key)
      {:ok, "secret"} = Crypto.decrypt(blob, key)
  """
  @spec encrypt(binary(), key()) :: {:ok, String.t()} | {:error, :invalid_key}
  def encrypt(plaintext, key) when is_binary(plaintext) do
    with :ok <- validate_key(key) do
      iv = :crypto.strong_rand_bytes(@iv_size)

      {ciphertext, tag} =
        :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, @aad, @tag_size, true)

      {:ok, Base.encode64(<<@version, iv::binary, tag::binary, ciphertext::binary>>)}
    end
  end

  @doc """
  Decrypts a blob produced by `encrypt/2`.

  Returns `{:error, :decrypt_failed}` when the key is wrong or the blob
  was tampered with, and `{:error, :invalid_blob}` when the input is not
  a blob produced by `encrypt/2`.
  """
  @spec decrypt(String.t(), key()) ::
          {:ok, binary()} | {:error, :invalid_key | :invalid_blob | :decrypt_failed}
  def decrypt(blob, key) when is_binary(blob) do
    with :ok <- validate_key(key),
         {:ok, data} <- decode_blob(blob),
         <<@version, iv::binary-size(@iv_size), tag::binary-size(@tag_size), ciphertext::binary>> <-
           data do
      case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, @aad, tag, false) do
        :error -> {:error, :decrypt_failed}
        plaintext -> {:ok, plaintext}
      end
    else
      {:error, _} = error -> error
      _malformed -> {:error, :invalid_blob}
    end
  end

  defp decode_blob(blob) do
    case Base.decode64(blob) do
      {:ok, data} -> {:ok, data}
      :error -> {:error, :invalid_blob}
    end
  end

  defp validate_key(key) when is_binary(key) and byte_size(key) == @key_size, do: :ok
  defp validate_key(_key), do: {:error, :invalid_key}
end
