defmodule ProtoRune.Atproto.Identity.HandleResolver do
  @moduledoc """
  Handles AT Protocol handle resolution to DIDs through DNS and HTTPS methods.

  Implements the handle resolution specification from AT Protocol:
  - DNS TXT record lookup at _atproto.<handle>
  - HTTPS lookup at https://<handle>/.well-known/atproto-did
  """

  alias ProtoRune.HTTPClient

  require Logger

  @type resolution_opts :: [
          timeout: pos_integer(),
          retry_count: non_neg_integer()
        ]

  @type error_reason ::
          :not_found
          | :network_error
          | :invalid_response
          | :timeout

  @default_timeout 5000
  @default_retries 2

  @doc """
  Attempts to resolve a handle to a DID using DNS TXT records.

  Looks for a TXT record at _atproto.<handle> that starts with "did=".
  """
  @spec resolve_dns(String.t(), resolution_opts()) :: {:ok, String.t()} | {:error, error_reason()}
  def resolve_dns(handle, opts \\ []) do
    dns_name = "_atproto.#{handle}"
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    retries = Keyword.get(opts, :retry_count, @default_retries)

    do_resolve_dns(dns_name, timeout, retries)
  end

  @doc """
  Attempts to resolve a handle to a DID using HTTPS lookup.

  Makes a GET request to https://<handle>/.well-known/atproto-did.
  """
  @spec resolve_https(String.t(), resolution_opts()) :: {:ok, String.t()} | {:error, error_reason()}
  def resolve_https(handle, opts \\ []) do
    url = "https://#{handle}/.well-known/atproto-did"
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    retries = Keyword.get(opts, :retry_count, @default_retries)

    do_resolve_https(url, timeout, retries)
  end

  # Private Functions

  defp do_resolve_dns(dns_name, timeout, retries) do
    case :inet_res.lookup(to_charlist(dns_name), :in, :txt, timeout: timeout) do
      [] ->
        {:error, :not_found}

      records when is_list(records) ->
        records
        |> Enum.map(&List.to_string/1)
        |> find_did_record()
        |> handle_did_record()

      _ when retries > 0 ->
        Logger.warning("DNS resolution failed for #{dns_name}, retrying...")
        do_resolve_dns(dns_name, timeout, retries - 1)

      _ ->
        {:error, :network_error}
    end
  end

  defp do_resolve_https(url, timeout, retries) do
    case HTTPClient.request(:get, url, timeout: timeout) do
      {:ok, %{status: 200, body: body, headers: headers}} ->
        with true <- text_response?(headers),
             {:ok, did} <- validate_did_response(body) do
          {:ok, did}
        else
          _ -> {:error, :invalid_response}
        end

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      _ when retries > 0 ->
        Logger.warning("HTTPS resolution failed for #{url}, retrying...")
        do_resolve_https(url, timeout, retries - 1)

      err ->
        Logger.error("HTTPS resolution failed for #{url}: #{inspect(err)}")
        {:error, :network_error}
    end
  end

  defp find_did_record(records) do
    Enum.find_value(records, fn record ->
      record
      |> to_string()
      |> String.trim()
      |> case do
        "did=" <> did -> did
        _ -> nil
      end
    end)
  end

  defp handle_did_record(nil), do: {:error, :not_found}
  defp handle_did_record(did), do: {:ok, String.trim(did)}

  defp text_response?(headers) do
    Enum.any?(headers, fn {k, v} ->
      String.downcase(k) == "content-type" &&
        String.starts_with?(String.downcase(v), "text/plain")
    end)
  end

  defp validate_did_response(body) do
    did = String.trim(body)

    if String.match?(did, ~r/^did:(plc|web):[a-zA-Z0-9._:%-]+$/) do
      {:ok, did}
    else
      {:error, :invalid_response}
    end
  end
end
