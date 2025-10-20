defmodule ProtoRune.Atproto.Repo do
  @moduledoc false

  import ProtoRune.XRPC.DSL

  @collections [:generator, :like, :post, :postgate, :repost, :threadgate]

  @strong_ref_t %{uri: {:required, :string}, cid: {:required, :string}}

  @like_t %{
    subject: {:required, @strong_ref_t},
    created_at: {:naive_datetime, {:default, &NaiveDateTime.utc_now/0}}
  }

  @byte_slice_t %{
    byte_start: {:required, {:integer, {:gte, 0}}},
    byte_end: {:required, {:integer, {:gte, 0}}}
  }
  @link_t %{uri: {:required, :string}}
  @tag_t %{tag: {:required, {:string, {:max, 640}}}}
  @mention_t %{did: {:required, :string}}
  @facet_t %{
    index: {:required, @byte_slice_t},
    features: {:required, {:list, {:oneof, [@link_t, @tag_t, @mention_t]}}}
  }
  @self_label_t %{val: {:required, {:string, {:max, 128}}}}
  @post_t %{
    text: {:required, {:string, {:max, 300}}},
    reply: %{root: {:required, @strong_ref_t}, parent: {:required, @strong_ref_t}},
    langs: {:list, :string},
    facets: {:list, @facet_t},
    tags: {:list, {:string, {:max, 640}}},
    labels: {:list, %{values: {:list, @self_label_t}}},
    created_at: {:naive_datetime, {:default, &NaiveDateTime.utc_now/0}}
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
  defquery "com.atproto.repo.getRecord", authenticated: true do
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
  defquery "com.atproto.repo.listRecords", authenticated: true do
    param :repo, {:required, :string}
    param :collection, {:required, :string}
    param :limit, {:integer, {:range, {1, 100}}}
    param :cursor, :string
    param :reverse, :boolean
  end

  def encode_collection(col), do: "app.bsky.feed.#{col}"

  def parse_record_schema(%{collection: :post}), do: {:ok, @post_t}
  def parse_record_schema(%{collection: :like}), do: {:ok, @like_t}
end
