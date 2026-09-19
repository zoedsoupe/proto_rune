defmodule ProtoRune.Commit do
  @moduledoc """
  Verification of signed repository commits.

  Every repository head is a commit block: a DAG-CBOR map with the repo's
  `did`, the MST root under `data`, a revision `rev`, the previous commit
  link `prev` (or null) and an ECDSA `sig` over the canonical DAG-CBOR
  encoding of the commit without the `sig` field.

  The signature is produced by the repo's signing key, advertised in the
  `#atproto` verification method of the repo's DID document. Both P-256
  (ES256) and secp256k1 (ES256K) keys are supported.

  This module is pure: it takes a decoded commit block and a DID document
  and never performs IO. `ProtoRune.Atproto.Sync.verify_checkout/2` wires
  it to DID resolution and CAR parsing.

  ## Examples

      {:ok, blocks} = Sync.parse_car(car)
      {:ok, commit_cid} = CAR.read(car) |> elem(1) |> Map.fetch!(:roots) |> List.first() |> ...
      :ok = Commit.verify(blocks[commit_cid], did_document)
  """

  alias ProtoRune.Atproto.Identity.SigningKey
  alias ProtoRune.CBOR

  @typedoc "A decoded commit block, as found under a checkout CAR's root CID."
  @type commit :: %{String.t() => term()}

  @doc """
  Verifies a decoded commit block against a DID document.

  Checks that the commit's `did` matches the document, extracts the
  `#atproto` signing key, and verifies `sig` over the canonical DAG-CBOR
  encoding of the commit without `sig`. Returns `:ok` or
  `{:error, reason}`.
  """
  @spec verify(commit(), map()) :: :ok | {:error, atom()}
  def verify(%{"did" => did, "sig" => sig} = commit, did_document) when is_binary(sig) and byte_size(sig) == 64 do
    with :ok <- check_did(did, did_document),
         {:ok, point, curve} <- SigningKey.from_did_doc(did_document) do
      unsigned = unsigned_bytes(commit)

      if SigningKey.verify(point, curve, unsigned, sig) do
        :ok
      else
        {:error, :invalid_signature}
      end
    end
  end

  def verify(%{"sig" => _sig}, _did_document), do: {:error, :invalid_signature_encoding}
  def verify(_commit, _did_document), do: {:error, :invalid_commit}

  @doc """
  Returns the canonical DAG-CBOR encoding a commit's signature covers:
  the commit map without its `sig` field.
  """
  @spec unsigned_bytes(commit()) :: binary()
  def unsigned_bytes(%{} = commit), do: commit |> Map.delete("sig") |> CBOR.encode()

  defp check_did(did, %{id: did}), do: :ok
  defp check_did(_did, _doc), do: {:error, :did_mismatch}
end
