defmodule ProtoRune.Atproto.Repo do
  @moduledoc """
  Low-level `com.atproto.repo` operations.

  Create, read, update, delete, and list records in a repository.
  Write operations require an authenticated `ProtoRune.Atproto.Session`;
  read operations (`get_record`, `list_records`) accept an optional session.

  For common Bluesky actions (posting, liking, reposting) prefer the
  high-level `ProtoRune` API, which wraps these calls with the right
  collections and record schemas.
  """

  import ProtoRune.XRPC.DSL

  alias ProtoRune.XRPC.Client
  alias ProtoRune.XRPC.Procedure

  @collections [:generator, :like, :post, :postgate, :repost, :threadgate]

  @strong_ref_t %{uri: {:required, :string}, cid: {:required, :string}}

  @like_t %{
    "$type": {:required, :string},
    subject: {:required, @strong_ref_t},
    created_at: :string
  }

  @repost_t %{
    "$type": {:required, :string},
    subject: {:required, @strong_ref_t},
    created_at: :string
  }

  @byte_slice_t %{
    byte_start: {:required, {:integer, {:gte, 0}}},
    byte_end: {:required, {:integer, {:gte, 0}}}
  }
  @link_t %{"$type": {:required, :string}, uri: {:required, :string}}
  @tag_t %{"$type": {:required, :string}, tag: {:required, {:string, {:max, 640}}}}
  @mention_t %{"$type": {:required, :string}, did: {:required, :string}}
  @facet_t %{
    index: {:required, @byte_slice_t},
    features: {:required, {:list, {:oneof, [@link_t, @tag_t, @mention_t]}}}
  }
  @self_label_t %{val: {:required, {:string, {:max, 128}}}}
  @post_t %{
    "$type": {:required, :string},
    text: {:required, {:string, {:max, 300}}},
    reply: %{root: {:required, @strong_ref_t}, parent: {:required, @strong_ref_t}},
    langs: {:list, :string},
    facets: {:list, @facet_t},
    tags: {:list, {:string, {:max, 640}}},
    labels: {:list, %{values: {:list, @self_label_t}}},
    created_at: :string
  }

  @doc """
  Create a single new repository record. Requires auth, implemented by PDS.

  https://docs.bsky.app/docs/api/com-atproto-repo-create-record
  """
  defprocedure "com.atproto.repo.createRecord", authenticated: true do
    param :repo, {:required, :string}
    param :rkey, {:string, {:max, 15}}
    param :validate, :boolean
    param :swap_commit, :string

    param :collection,
          {:required, {{:enum, @collections}, {:transform, {__MODULE__, :encode_collection}}}}

    param :record,
          {:required, {:dependent, {__MODULE__, :parse_record_schema}}}
  end

  @doc """
  Get a single record from a repository. Does not require auth.

  https://docs.bsky.app/docs/api/com-atproto-repo-get-record
  """
  defquery "com.atproto.repo.getRecord", authenticated: :optional do
    param :repo, {:required, :string}
    param :collection, {:required, :string}
    param :rkey, {:required, :string}
    param :cid, :string
  end

  @doc """
  Write a repository record, creating or updating it as needed. Requires auth, implemented by PDS.

  https://docs.bsky.app/docs/api/com-atproto-repo-put-record
  """
  defprocedure "com.atproto.repo.putRecord", authenticated: true do
    param :repo, {:required, :string}
    param :collection, {:required, :string}
    param :rkey, {:required, :string}
    param :validate, :boolean
    param :record, {:required, :map}
    param :swap_record, :string
    param :swap_commit, :string
  end

  @doc """
  Delete a repository record, or ensure it doesn't exist. Requires auth, implemented by PDS.

  https://docs.bsky.app/docs/api/com-atproto-repo-delete-record
  """
  defprocedure "com.atproto.repo.deleteRecord", authenticated: true do
    param :repo, {:required, :string}
    param :collection, {:required, :string}
    param :rkey, {:required, :string}
    param :swap_record, :string
    param :swap_commit, :string
  end

  @doc """
  List a range of records in a repository, matching a specific collection. Does not require auth.

  https://docs.bsky.app/docs/api/com-atproto-repo-list-records
  """
  defquery "com.atproto.repo.listRecords", authenticated: :optional do
    param :repo, {:required, :string}
    param :collection, {:required, :string}
    param :limit, {:integer, {:range, {1, 100}}}
    param :cursor, :string
    param :reverse, :boolean
  end

  def encode_collection(col), do: "app.bsky.feed.#{col}"

  def parse_record_schema(%{collection: :post}), do: {:ok, @post_t}
  def parse_record_schema(%{collection: :like}), do: {:ok, @like_t}
  def parse_record_schema(%{collection: :repost}), do: {:ok, @repost_t}

  def parse_record_schema(%{collection: collection}), do: {:error, {:unsupported_collection, collection}}

  @doc """
  Upload a blob of binary data to be stored with the account, for later
  reference in repository records (for example, a profile avatar).
  Requires auth, implemented by PDS.

  Returns `{:ok, %{blob: blob}}` where `blob` is a blob reference map
  suitable for embedding in a record.

  https://docs.bsky.app/docs/api/com-atproto-repo-upload-blob

  ## Examples

      {:ok, %{blob: blob}} = Repo.upload_blob(session, image_data, "image/png")
  """
  @spec upload_blob(map(), binary(), String.t()) :: {:ok, map()} | {:error, term()}
  def upload_blob(%{access_jwt: access_token} = session, data, content_type)
      when is_binary(data) and is_binary(content_type) do
    base_url = Map.get(session, :service_url)

    "com.atproto.repo.uploadBlob"
    |> Procedure.new(base_url: base_url)
    |> Procedure.put_raw_body(data)
    |> Procedure.put_header(:authorization, "Bearer #{access_token}")
    |> Procedure.put_header("content-type", content_type)
    |> Client.execute()
  end
end
