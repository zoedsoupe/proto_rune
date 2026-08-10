defmodule ProtoRune.Atproto.OAuth.Session do
  @moduledoc """
  An OAuth-authenticated AT Protocol session.

  Returned by `ProtoRune.Atproto.OAuth.exchange_code/3` and
  `ProtoRune.Atproto.OAuth.refresh/2`. Unlike
  `ProtoRune.Atproto.Session` (app password sessions), OAuth access tokens
  are DPoP-bound: requests must carry a DPoP proof signed with `dpop_key`
  instead of a plain `Bearer` header.

  Treat it as an opaque value. The `dpop_key` is sensitive key material:
  store it with the same care as the tokens.
  """

  alias ProtoRune.Atproto.OAuth.DPoP

  @type t :: %__MODULE__{
          did: String.t(),
          handle: String.t() | nil,
          access_token: String.t(),
          refresh_token: String.t() | nil,
          token_type: String.t() | nil,
          scope: String.t() | nil,
          expires_at: integer() | nil,
          service_url: String.t() | nil,
          issuer: String.t() | nil,
          token_endpoint: String.t() | nil,
          dpop_key: DPoP.private_key(),
          dpop_jwk: DPoP.jwk(),
          dpop_nonce: String.t() | nil
        }

  @enforce_keys [:did, :access_token, :dpop_key, :dpop_jwk]
  defstruct @enforce_keys ++
              [
                :handle,
                :refresh_token,
                :token_type,
                :scope,
                :expires_at,
                :service_url,
                :issuer,
                :token_endpoint,
                :dpop_nonce
              ]

  @doc """
  Builds a session from a token endpoint response.

  `data` is the decoded JSON response body (string keys). `context` carries
  flow state such as the resolved `service_url`, `issuer`, DPoP key
  material and the account `handle` when known.
  """
  @spec parse(map(), map()) :: {:ok, t()} | {:error, :invalid_token_response}
  def parse(data, context) when is_map(data) and is_map(context) do
    case data do
      %{"access_token" => access_token, "sub" => did} ->
        {:ok,
         %__MODULE__{
           did: did,
           handle: Map.get(context, :handle),
           access_token: access_token,
           refresh_token: Map.get(data, "refresh_token"),
           token_type: Map.get(data, "token_type"),
           scope: Map.get(data, "scope"),
           expires_at: expires_at(Map.get(data, "expires_in")),
           service_url: Map.get(context, :service_url),
           issuer: Map.get(context, :issuer),
           token_endpoint: Map.get(context, :token_endpoint),
           dpop_key: Map.fetch!(context, :dpop_key),
           dpop_jwk: Map.fetch!(context, :dpop_jwk),
           dpop_nonce: Map.get(context, :dpop_nonce)
         }}

      _ ->
        {:error, :invalid_token_response}
    end
  end

  defp expires_at(nil), do: nil

  defp expires_at(expires_in) when is_integer(expires_in) do
    System.system_time(:second) + expires_in
  end
end
