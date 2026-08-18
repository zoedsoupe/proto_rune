defmodule ProtoRune.Atproto.Session do
  @moduledoc """
  An authenticated AT Protocol session.

  Returned by `ProtoRune.login/2` and `ProtoRune.refresh_session/1`.
  Carries the access and refresh JWTs, the account's `handle` and `did`,
  and the `service_url` of the PDS resolved from the DID document, so
  requests are routed to the right server.

  Treat it as an opaque value: pass it as the first argument to any
  function that requires authentication, and refresh it with
  `ProtoRune.refresh_session/1` when the access token expires.
  """

  @behaviour ProtoRune.Session

  @type t :: %__MODULE__{
          access_jwt: String.t(),
          refresh_jwt: String.t(),
          handle: String.t(),
          did: String.t(),
          service_url: String.t() | nil,
          active: boolean() | nil,
          email: String.t() | nil,
          email_auth_factor: boolean() | nil,
          email_confirmed: boolean() | nil,
          did_doc: map() | nil
        }

  @t %{
    access_jwt: {:required, :string},
    refresh_jwt: {:required, :string},
    handle: {:required, :string},
    did: {:required, :string},
    service_url: :string,
    active: :boolean,
    email: :string,
    email_auth_factor: :boolean,
    email_confirmed: :boolean,
    did_doc: %{
      id: :string,
      service:
        {:list,
         %{
           id: :string,
           type: :string,
           service_endpoint: :string
         }},
      "@context": {:list, :string},
      also_known_as: {:list, :string},
      verification_method:
        {:list,
         %{
           id: :string,
           type: :string,
           controller: :string,
           public_key_multibase: :string
         }}
    }
  }

  defstruct Map.keys(@t)

  @impl true
  def service_url(%__MODULE__{} = session), do: session.service_url

  @impl true
  def authorization_headers(%__MODULE__{} = session, _method, _url) do
    {:ok, %{"authorization" => "Bearer #{session.access_jwt}"}, session}
  end

  @doc """
  Parses session data from the server response.

  Extracts the service URL from the DID document if available,
  allowing the session to carry its own service endpoint.

  ## Examples

      {:ok, session} = Session.parse(%{
        access_jwt: "...",
        refresh_jwt: "...",
        did: "did:plc:...",
        handle: "alice.bsky.social"
      })
  """
  def parse(data) when is_map(data) do
    # Extract service_url from did_doc if present
    service_url = extract_service_url(data)

    session_data = Map.put(data, :service_url, service_url)
    {:ok, struct(__MODULE__, session_data)}
  end

  @doc """
  Normalizes a service URL into an XRPC base URL.

  DID documents list the PDS endpoint without the `/xrpc` path that XRPC
  methods are served under, so it is appended when missing.

      iex> Session.normalize_service_url("https://bsky.social")
      "https://bsky.social/xrpc"

      iex> Session.normalize_service_url("https://bsky.social/xrpc")
      "https://bsky.social/xrpc"
  """
  @spec normalize_service_url(String.t()) :: String.t()
  def normalize_service_url(url) when is_binary(url) do
    url = String.trim_trailing(url, "/")

    if String.ends_with?(url, "/xrpc") do
      url
    else
      url <> "/xrpc"
    end
  end

  defp extract_service_url(%{did_doc: %{service: services}}) when is_list(services) do
    # Look for ATProto PDS service endpoint
    case Enum.find(services, &(&1[:type] == "AtprotoPersonalDataServer")) do
      %{service_endpoint: url} -> normalize_service_url(url)
      _ -> nil
    end
  end

  defp extract_service_url(_), do: nil
end
