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

  def encode_collection(col), do: "app.bsky.feed.#{col}"

  def parse_record_schema(%{collection: :post}), do: {:ok, @post_t}
  def parse_record_schema(%{collection: :like}), do: {:ok, @like_t}
end
