defmodule ATProto.Identity do
  @moduledoc """
  Implements AT Protocol identity management operations.

  Provides functionality for:
  - Resolving handles to DIDs
  - Resolving DIDs to DID documents
  - Validating identity chains
  - Verifying signatures
  """

  @behaviour ATProto.Identity.Behaviour

  alias ATProto.Identity.Cache
  alias ATProto.Identity.DIDResolver
  alias ATProto.Identity.HandleResolver

  require Logger

  # Constants for timeouts and retries
  @dns_timeout :timer.seconds(5)
  @http_timeout :timer.seconds(10)

  @impl true
  defguard is_did(term)
           when is_binary(term) and
                  byte_size(term) > 7 and
                  binary_part(term, 0, 4) == "did:" and
                  binary_part(term, 4, 4) in ["plc:", "web:"]

  # Since handle validation is quite complex for guards alone,
  # we'll do basic structural validation in the guard and leave
  # complete validation for valid_handle?
  @impl true
  defguard is_handle(term)
           # Must have at least one dot
           # Cannot start or end with hyphen
           when is_binary(term) and
                  byte_size(term) > 3 and
                  binary_part(term, 0, 1) != "." and
                  binary_part(term, byte_size(term) - 1, 1) != "." and
                  binary_part(term, 0, 1) != "-" and
                  binary_part(term, byte_size(term) - 1, 1) != "-"

  @doc """
  Performs complete syntactic validation of a handle.

  Validates according to AT Protocol handle specification:
  - Must be at least two segments separated by dots
  - Each segment must be 1-63 chars
  - Segments must start/end with alphanumeric
  - Segments can contain hyphens (not at start/end)
  - Last segment cannot start with a number
  """
  @impl true
  def valid_handle?(term) when is_handle(term) do
    segments = String.split(term, ".")

    # Must have at least 2 segments
    if length(segments) < 2, do: false

    # Last segment cannot start with digit
    [last_segment | other_segments] = Enum.reverse(segments)

    case String.first(last_segment) do
      <<char>> when char in ?0..?9 ->
        false

      _ ->
        # Validate each segment
        Enum.all?([last_segment | other_segments], &valid_segment?/1)
    end
  end

  def valid_handle?(_), do: false

  @doc """
  Performs complete syntactic validation of a DID according to AT Protocol specifications.

  A valid DID must:
  - Start with "did:"
  - Have a supported method (plc or web)
  - Contain a valid method-specific identifier
  - Use only allowed characters (a-z, A-Z, 0-9, ., _, :, %, -)
  """
  @impl true
  def valid_did?(term) when is_did(term) do
    case String.split(term, ":", parts: 3) do
      ["did", method, identifier] ->
        valid_method?(method) and valid_identifier?(method, identifier)

      _ ->
        false
    end
  end

  def valid_did?(_), do: false

  defp valid_method?(method) do
    method in ["plc", "web"]
  end

  # Method-specific identifier validation
  defp valid_identifier?("plc", identifier) do
    # PLC identifiers should:
    # - Not be empty
    # - Contain only allowed characters
    # - Not start or end with special characters
    byte_size(identifier) > 0 and
      String.match?(identifier, ~r/^[a-zA-Z0-9][a-zA-Z0-9._:%-]*[a-zA-Z0-9]$/)
  end

  defp valid_identifier?("web", identifier) do
    # Web DID identifiers should:
    # - Be valid domain names
    # - Support percent encoding for colons
    # - Not include paths or query parameters
    String.match?(identifier, ~r/^([a-zA-Z0-9][a-zA-Z0-9-]*\.)+[a-zA-Z]{2,}$/) or
      String.match?(identifier, ~r/^([a-zA-Z0-9][a-zA-Z0-9-]*\.)+[a-zA-Z]{2,}%3A\d+$/)
  end

  defp valid_identifier?(_, _), do: false

  # Validates a single handle segment
  defp valid_segment?(segment) do
    byte_size = byte_size(segment)

    # Length between 1-63
    # Must start with alphanumeric
    # Must end with alphanumeric
    # Can only contain alphanumeric and hyphen
    byte_size in 1..63 and
      String.match?(String.first(segment), ~r/^[a-zA-Z0-9]$/) and
      String.match?(String.last(segment), ~r/^[a-zA-Z0-9]$/) and
      String.match?(segment, ~r/^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$/)
  end

  @impl true
  def resolve_handle(handle) when is_handle(handle) do
    if valid_handle?(handle) do
      with {:error, _} <- Cache.get_did(handle),
           {:error, _} <- HandleResolver.resolve_dns(handle, timeout: @dns_timeout),
           {:ok, did} <- HandleResolver.resolve_https(handle, timeout: @http_timeout) do
        Cache.put_did(handle, did)
        {:ok, did}
      end
    else
      {:error, :invalid_format}
    end
  end

  def resolve_handle(_), do: {:error, :invalid_format}

  @impl true
  def resolve_did(did) when is_did(did) do
    if valid_did?(did) do
      with {:error, _} <- Cache.get_did_doc(did),
           {:ok, doc} <- DIDResolver.resolve(did) do
        Cache.put_did_doc(did, doc)
        {:ok, doc}
      end
    else
      {:error, :invalid_format}
    end
  end

  def resolve_did(_), do: {:error, :invalid_format}

  @impl true
  def validate_identity(handle) when is_handle(handle) do
    with {:ok, did} <- resolve_handle(handle),
         {:ok, doc} <- resolve_did(did),
         :ok <- verify_handle_binding(doc, handle) do
      {:ok, doc}
    end
  end

  def validate_identity(_), do: {:error, :invalid_format}

  @impl true
  def verify_signature(did, message, _signature) when is_binary(did) and is_binary(message) do
    raise "not implemented"
  end

  def verify_signature(_, _, _), do: {:error, :invalid_format}

  @impl true
  def refresh_handle(handle) when is_binary(handle) do
    Cache.invalidate_handle(handle)
  end

  @impl true
  def refresh_did(did) when is_binary(did) do
    Cache.invalidate_did(did)
  end

  # Private Functions

  defp verify_handle_binding(doc, handle) do
    if Enum.any?(doc.also_known_as, &(&1 == "at://#{handle}")) do
      :ok
    else
      {:error, :invalid_binding}
    end
  end
end
