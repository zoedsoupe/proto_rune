defmodule ProtoRune.Atproto.Identity.DIDResolver do
  @moduledoc """
  Handles DID resolution for AT Protocol identities.

  Supports two DID methods:
  - did:plc - Resolves through the PLC directory
  - did:web - Resolves through .well-known DID documents
  """

  alias ProtoRune.HTTPClient.SSRF

  require Logger

  @type did :: String.t()
  @type did_document :: %{
          id: did(),
          handle: String.t() | nil,
          service_endpoint: String.t(),
          verification_method: [map()],
          also_known_as: [String.t()]
        }

  @type error_reason ::
          :not_found
          | :network_error
          | :invalid_format
          | :unsupported_did_method
          | :rate_limited
          | :did_mismatch
          | {:http_error, pos_integer()}

  @type resolution_opts :: [
          timeout: pos_integer(),
          retry_count: non_neg_integer()
        ]

  @default_timeout 10_000
  @default_retries 2
  @plc_directory_url "https://plc.directory"

  @doc """
  Resolves a DID to its full DID document.

  Supports did:plc and did:web methods.
  """
  @spec resolve(did(), resolution_opts()) :: {:ok, did_document()} | {:error, error_reason()}
  def resolve(did, opts \\ [])

  def resolve("did:plc:" <> _ = did, opts) do
    resolve_plc(did, opts)
  end

  def resolve("did:web:" <> _ = did, opts) do
    resolve_web(did, opts)
  end

  def resolve(_, _), do: {:error, :unsupported_did_method}

  @doc """
  Resolves a DID through the PLC directory.
  """
  @spec resolve_plc(did(), resolution_opts()) :: {:ok, did_document()} | {:error, error_reason()}
  def resolve_plc(did, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    retries = Keyword.get(opts, :retry_count, @default_retries)

    url = "#{@plc_directory_url}/#{did}"

    # The DID in the path is stranger-chosen, so the fetch is guarded.
    case SSRF.get(url, [timeout: timeout] ++ http_opts(opts)) do
      {:ok, %{status: 200, body: body}} ->
        decode_did_document(body, did)

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      _ when retries > 0 ->
        Logger.warning("PLC resolution failed for #{did}, retrying...")
        resolve_plc(did, Keyword.put(opts, :retry_count, retries - 1))

      _ ->
        {:error, :network_error}
    end
  end

  @doc """
  Resolves a DID through the web DID document method.
  """
  @spec resolve_web(did(), resolution_opts()) :: {:ok, did_document()} | {:error, error_reason()}
  def resolve_web(did, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    retries = Keyword.get(opts, :retry_count, @default_retries)

    with {:ok, domain} <- extract_domain(did),
         {:ok, response} <- fetch_well_known_document(domain, timeout, http_opts(opts)) do
      decode_did_document(response.body, did)
    else
      {:error, :invalid_domain} ->
        {:error, :invalid_format}

      {:error, :not_found} when retries > 0 ->
        Logger.warning("Web DID resolution failed for #{did}, retrying...")
        resolve_web(did, Keyword.put(opts, :retry_count, retries - 1))

      error ->
        error
    end
  end

  defp extract_domain("did:web:" <> domain) do
    domain = String.replace(domain, "%3A", ":")

    if String.match?(domain, ~r/^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/) do
      {:ok, domain}
    else
      {:error, :invalid_domain}
    end
  end

  defp fetch_well_known_document(domain, timeout, http_opts) do
    url = "https://#{domain}/.well-known/did.json"

    # The domain comes from the DID string, so the fetch is guarded.
    case SSRF.get(url, [timeout: timeout] ++ http_opts) do
      {:ok, %{status: 200} = response} -> {:ok, response}
      {:ok, %{status: 404}} -> {:error, :not_found}
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      _ -> {:error, :network_error}
    end
  end

  defp http_opts(opts), do: Keyword.get(opts, :http, [])

  # The document's id must equal the resolved DID: a did:web host may serve another account's document.
  defp decode_did_document(body, did) do
    case JSON.decode(body) do
      {:ok, %{"id" => ^did} = doc} ->
        {:ok, ProtoRune.Case.snakelize_enum(doc)}

      {:ok, %{"id" => _other}} ->
        {:error, :did_mismatch}

      _ ->
        {:error, :invalid_format}
    end
  end
end
