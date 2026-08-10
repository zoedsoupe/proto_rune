defmodule ProtoRune.Atproto.OAuth.Client do
  @moduledoc """
  An AT Protocol OAuth public client.

  Holds the client configuration used across the authorization flow: the
  `client_id` (a URL pointing to the client metadata document), the
  `redirect_uri` registered in that document, the requested `scope` and the
  DPoP key pair used to prove possession of issued tokens.

  Build one with `new/1` and pass it to the functions in
  `ProtoRune.Atproto.OAuth`.

  ## Client metadata

  AT Protocol public clients identify themselves with a `client_id` URL
  that serves a client metadata document (RFC 7591 style). See
  https://atproto.com/specs/oauth for the required fields.

  ## Examples

      {:ok, client} =
        Client.new(
          client_id: "https://myapp.example.com/oauth/client-metadata.json",
          redirect_uri: "https://myapp.example.com/oauth/callback"
        )
  """

  alias ProtoRune.Atproto.OAuth.DPoP

  @default_scope "atproto transition:generic"

  @type t :: %__MODULE__{
          client_id: String.t(),
          redirect_uri: String.t(),
          scope: String.t(),
          dpop_key: DPoP.private_key(),
          dpop_jwk: DPoP.jwk()
        }

  @enforce_keys [:client_id, :redirect_uri, :dpop_key, :dpop_jwk]
  defstruct @enforce_keys ++ [scope: @default_scope]

  @doc """
  Creates a new OAuth client.

  ## Options

  - `:client_id` - Required. URL of the client metadata document.
  - `:redirect_uri` - Required. Callback URL registered in the client metadata.
  - `:scope` - Requested scope (default: `"atproto transition:generic"`).
  - `:dpop_key` - Existing 32-byte ES256 private key. When omitted, a fresh
    key pair is generated.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, :missing_client_id | :missing_redirect_uri}
  def new(opts) when is_list(opts) do
    with {:ok, client_id} <- fetch_opt(opts, :client_id),
         {:ok, redirect_uri} <- fetch_opt(opts, :redirect_uri) do
      {dpop_key, dpop_jwk} = dpop_keys(Keyword.get(opts, :dpop_key))

      {:ok,
       %__MODULE__{
         client_id: client_id,
         redirect_uri: redirect_uri,
         scope: Keyword.get(opts, :scope, @default_scope),
         dpop_key: dpop_key,
         dpop_jwk: dpop_jwk
       }}
    end
  end

  defp fetch_opt(opts, key) do
    case Keyword.get(opts, key) do
      value when is_binary(value) -> {:ok, value}
      _ -> {:error, :"missing_#{key}"}
    end
  end

  defp dpop_keys(nil), do: DPoP.generate_key()

  defp dpop_keys(key) when is_binary(key) and byte_size(key) == 32 do
    {key, DPoP.public_jwk(key)}
  end
end
