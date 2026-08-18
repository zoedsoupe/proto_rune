defmodule ProtoRune.Atproto.Sync do
  @moduledoc """
  Low-level `com.atproto.sync` read operations.

  These are public PDS endpoints: no session and no auth headers are
  involved. Every function takes the base URL of the origin PDS as its
  first argument (the bare URL or the `/xrpc`-suffixed one; it is
  normalized internally), so the caller explicitly targets the PDS that
  hosts the repository.

  `get_repo/2` returns the repository as a CAR (Content Addressable
  aRchive) file. Use `parse_car/1` to decode it into a map of
  `ProtoRune.CID` => decoded block, and `ProtoRune.MST` to enumerate the
  records it contains.

  ## Trust model

  Checkouts are trusted against the source PDS: no commit or signature
  verification is performed. If you cannot trust the PDS you are reading
  from, verify the commit chain yourself before consuming the data.

  ## Examples

      {:ok, %{content_type: _, body: car}} =
        Sync.get_repo("https://pds.example.com", "did:plc:ewvi7nxzyoun6zhxrhs64oiz")

      {:ok, blocks} = Sync.parse_car(car)
  """

  alias ProtoRune.Atproto.Session
  alias ProtoRune.CAR
  alias ProtoRune.CBOR
  alias ProtoRune.CID
  alias ProtoRune.XRPC.Client
  alias ProtoRune.XRPC.Query

  @doc """
  Get information about an account's repository, including its current
  head commit. `repo` is a handle or a DID. Does not require auth,
  implemented by PDS.

  https://docs.bsky.app/docs/api/com-atproto-sync-describe-repo
  """
  @spec describe_repo(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def describe_repo(pds_url, repo) when is_binary(pds_url) and is_binary(repo) do
    "com.atproto.sync.describeRepo"
    |> Query.new(base_url: Session.normalize_service_url(pds_url))
    |> Query.put_param(:repo, repo)
    |> Client.execute()
  end

  @doc """
  Get a single blob from a repository, for example an image attached to
  a record. Does not require auth, implemented by PDS.

  Returns `{:ok, %{content_type: content_type, body: body}}` with the raw
  blob bytes and the content type reported by the server (`nil` when the
  response carries no content-type header).

  https://docs.bsky.app/docs/api/com-atproto-sync-get-blob
  """
  @spec get_blob(String.t(), String.t(), String.t()) ::
          {:ok, %{content_type: String.t() | nil, body: binary()}} | {:error, term()}
  def get_blob(pds_url, did, cid) when is_binary(pds_url) and is_binary(did) and is_binary(cid) do
    "com.atproto.sync.getBlob"
    |> Query.new(base_url: Session.normalize_service_url(pds_url), response: :binary)
    |> Query.put_param(:did, did)
    |> Query.put_param(:cid, cid)
    |> Client.execute()
  end

  @doc """
  Download a repository checkout as a CAR file. Does not require auth,
  implemented by PDS.

  Returns `{:ok, %{content_type: content_type, body: car}}` where `car` is
  the raw CAR byte string; decode it with `parse_car/1`.

  https://docs.bsky.app/docs/api/com-atproto-sync-get-repo
  """
  @spec get_repo(String.t(), String.t()) ::
          {:ok, %{content_type: String.t() | nil, body: binary()}} | {:error, term()}
  def get_repo(pds_url, did) when is_binary(pds_url) and is_binary(did) do
    "com.atproto.sync.getRepo"
    |> Query.new(base_url: Session.normalize_service_url(pds_url), response: :binary)
    |> Query.put_param(:did, did)
    |> Client.execute()
  end

  @doc """
  Decodes a repository CAR into its blocks.

  Accepts either the raw CAR binary or the `{:ok, %{body: car}}` tuple
  returned by `get_repo/2`, and returns `{:ok, blocks}` where `blocks` is
  a map of `ProtoRune.CID` => DAG-CBOR decoded block. CID links inside
  decoded blocks keep their raw `{:tag, 42, bytes}` form and can be turned
  into `ProtoRune.CID` values with `ProtoRune.CID.from_link/1`.

  The CAR header's root CIDs (which identify the signed commit block) are
  not part of the returned map; read them with `ProtoRune.CAR.read/1` when
  needed. Pass the commit block's `data` CID to `ProtoRune.MST.entries/2`
  to enumerate the records of the checkout.
  """
  @spec parse_car(binary | {:ok, %{body: binary()}}) ::
          {:ok, %{CID.t() => term()}} | {:error, atom() | tuple()}
  def parse_car({:ok, %{body: body}}) when is_binary(body), do: parse_car(body)

  def parse_car(data) when is_binary(data) do
    with {:ok, car} <- CAR.read(data), do: decode_blocks(car.blocks, %{})
  end

  defp decode_blocks([], blocks), do: {:ok, blocks}

  defp decode_blocks([{cid, bytes} | rest], blocks) do
    case CBOR.decode(bytes) do
      {:ok, decoded, <<>>} -> decode_blocks(rest, Map.put(blocks, cid, decoded))
      {:ok, _decoded, _rest} -> {:error, :invalid_block}
      {:error, reason} -> {:error, reason}
    end
  end
end
