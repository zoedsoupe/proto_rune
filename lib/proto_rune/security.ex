defmodule ProtoRune.Security do
  @moduledoc """
  Safe defaults for persisting AT Protocol session tokens.

  Bot and app authors often need to keep a session across restarts, but
  an access/refresh JWT pair written to disk in plaintext is a liability.
  This module combines the two halves of a safer default:

    * `ProtoRune.Security.Crypto` - AES-256-GCM encryption of the
      session payload (`:crypto` only, no extra dependencies).
    * `ProtoRune.Security.TokenStore` - a behaviour for storage
      backends, with `ProtoRune.Security.TokenStore.Dets` as the
      default.

  The encryption key must be kept outside the token storage itself,
  typically in an environment variable or a secret manager:

      # once, to provision the key:
      key = ProtoRune.Security.generate_key()
      System.put_env("PROTO_RUNE_TOKEN_KEY", ProtoRune.Security.encode_key(key))

      # on boot:
      {:ok, key} = ProtoRune.Security.decode_key(System.fetch_env!("PROTO_RUNE_TOKEN_KEY"))

  Then persist and restore sessions with:

      :ok = ProtoRune.Security.save_session(session, key)
      {:ok, session} = ProtoRune.Security.load_session("did:plc:alice", key)
      :ok = ProtoRune.Security.delete_session("did:plc:alice")

  Sessions are keyed by their DID. To use another storage backend, pass
  a `{module, opts}` tuple implementing `ProtoRune.Security.TokenStore`
  as the last argument.
  """

  alias ProtoRune.Atproto.Session
  alias ProtoRune.Security.Crypto
  alias ProtoRune.Security.TokenStore

  @default_store {TokenStore.Dets, []}

  @doc """
  Generates a random 32-byte encryption key. See `Crypto.generate_key/0`.
  """
  @spec generate_key() :: Crypto.key()
  defdelegate generate_key(), to: Crypto

  @doc """
  Encodes a key as Base64 for storage in env vars or config. See `Crypto.encode_key/1`.
  """
  @spec encode_key(Crypto.key()) :: String.t()
  defdelegate encode_key(key), to: Crypto

  @doc """
  Decodes a Base64-encoded key. See `Crypto.decode_key/1`.
  """
  @spec decode_key(String.t()) ::
          {:ok, Crypto.key()} | {:error, :invalid_key_size | :invalid_key_encoding}
  defdelegate decode_key(encoded), to: Crypto

  @doc """
  Encrypts `session` and stores it under its DID in `store`.

  Returns `:ok` on success. `store` defaults to
  `{ProtoRune.Security.TokenStore.Dets, []}`.

  ## Examples

      :ok = ProtoRune.Security.save_session(session, key)
      :ok = ProtoRune.Security.save_session(session, key, {MyApp.TokenStore, []})
  """
  @spec save_session(Session.t(), Crypto.key(), TokenStore.backend()) :: :ok | {:error, term()}
  def save_session(%Session{did: did} = session, key, store \\ @default_store) do
    with {:ok, blob} <- Crypto.encrypt(:erlang.term_to_binary(session), key) do
      put(store, did, blob)
    end
  end

  @doc """
  Loads and decrypts the session stored under `did`.

  Returns `{:error, :not_found}` when no session is stored for `did`,
  `{:error, :decrypt_failed}` when the key is wrong or the stored blob
  was tampered with, and `{:error, :invalid_session}` when the decrypted
  payload is not a `ProtoRune.Atproto.Session`.

  ## Examples

      {:ok, session} = ProtoRune.Security.load_session("did:plc:alice", key)
  """
  @spec load_session(TokenStore.id(), Crypto.key(), TokenStore.backend()) ::
          {:ok, Session.t()} | {:error, term()}
  def load_session(did, key, store \\ @default_store) do
    with {:ok, blob} <- fetch(store, did),
         {:ok, plaintext} <- Crypto.decrypt(blob, key) do
      case :erlang.binary_to_term(plaintext) do
        %Session{} = session -> {:ok, session}
        _other -> {:error, :invalid_session}
      end
    end
  end

  @doc """
  Deletes the session stored under `did`. Deleting a missing session returns `:ok`.
  """
  @spec delete_session(TokenStore.id(), TokenStore.backend()) :: :ok | {:error, term()}
  def delete_session(did, store \\ @default_store), do: delete(store, did)

  defp put(store, id, blob), do: dispatch(store, :put, [id, blob])
  defp fetch(store, id), do: dispatch(store, :fetch, [id])
  defp delete(store, id), do: dispatch(store, :delete, [id])

  defp dispatch({backend, opts}, fun, args), do: apply(backend, fun, args ++ [opts])
end
