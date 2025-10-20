defmodule ProtoRune.Atproto.Identity.Behaviour do
  @moduledoc """
  Defines the behaviour for AT Protocol identity management operations.

  This behaviour specifies the contract for handling:
  - Handle resolution
  - DID resolution
  - Identity validation
  - Signature verification
  """

  @type handle :: String.t()
  @type did :: String.t()
  @type signature :: binary()
  @type message :: binary()

  @type did_document :: %{
          id: did(),
          handle: handle() | nil,
          service_endpoint: String.t(),
          verification_method: [map()],
          also_known_as: [String.t()]
        }

  @type error_reason ::
          :not_found
          | :network_error
          | :invalid_format
          | :unsupported_did_method
          | :invalid_signature
          | :rate_limited
          | {:http_error, pos_integer()}

  @doc """
  Resolves a handle to its corresponding DID.
  """
  @callback resolve_handle(handle()) ::
              {:ok, did()}
              | {:error, error_reason()}

  @doc """
  Resolves a DID to its full DID document.
  """
  @callback resolve_did(did()) ::
              {:ok, did_document()}
              | {:error, error_reason()}

  @doc """
  Validates the full identity chain from handle to DID document,
  ensuring bidirectional verification.
  """
  @callback validate_identity(handle()) ::
              {:ok, did_document()}
              | {:error, error_reason()}

  @doc """
  Verifies a signature against a DID's public key.
  """
  @callback verify_signature(did(), message(), signature()) ::
              :ok
              | {:error, error_reason()}

  @doc """
  Forces a refresh of cached handle resolution data.
  """
  @callback refresh_handle(handle()) :: :ok

  @doc """
  Forces a refresh of cached DID document.
  """
  @callback refresh_did(did()) :: :ok

  @doc """
  Guards for checking if a string is a valid handle format.
  """
  @callback is_handle(term()) :: boolean()

  @doc """
  Guards for checking if a string is a valid DID format.
  """
  @callback is_did(term()) :: boolean()

  @doc """
  Runtime check for valid handle format, syntactically.
  """
  @callback valid_handle?(term()) :: boolean()

  @doc """
  Runtime check for valid DID format, syntactically.
  """
  @callback valid_did?(term()) :: boolean()
end
