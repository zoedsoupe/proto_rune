defmodule ProtoRune.Security.TokenStore do
  @moduledoc """
  Behaviour for pluggable token storage backends.

  A backend persists opaque, already-encrypted blobs keyed by an account
  identifier (typically the account DID). Backends never see plaintext
  tokens: encryption and decryption happen in `ProtoRune.Security`
  before the blob reaches the store.

  `ProtoRune.Security.TokenStore.Dets` is the default implementation.
  Implement this behaviour to store tokens elsewhere (a database, a
  system keyring, Redis, etc):

      defmodule MyApp.DBTokenStore do
        @behaviour ProtoRune.Security.TokenStore

        @impl true
        def put(id, blob, _opts), do: MyApp.Repo.upsert_token(id, blob)

        @impl true
        def fetch(id, _opts), do: MyApp.Repo.get_token(id)

        @impl true
        def delete(id, _opts), do: MyApp.Repo.delete_token(id)
      end

  Then pass `{MyApp.DBTokenStore, []}` as the `store` argument to the
  `ProtoRune.Security` functions.
  """

  @typedoc "Account identifier used as the storage key, typically a DID."
  @type id :: String.t()

  @typedoc "Backend-specific options."
  @type opts :: keyword()

  @typedoc "A storage backend and its options."
  @type backend :: {module(), opts()}

  @doc "Persists the encrypted `blob` under `id`, overwriting any existing entry."
  @callback put(id(), blob :: binary(), opts()) :: :ok | {:error, term()}

  @doc """
  Fetches the blob stored under `id`.

  Returns `{:error, :not_found}` when no entry exists for `id`.
  """
  @callback fetch(id(), opts()) :: {:ok, binary()} | {:error, :not_found | term()}

  @doc "Deletes the entry stored under `id`. Deleting a missing entry returns `:ok`."
  @callback delete(id(), opts()) :: :ok | {:error, term()}
end
