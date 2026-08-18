defmodule ProtoRune.Firehose.Event do
  @moduledoc """
  A single event decoded from the ATProto firehose.

  ## Fields

    * `:type` - the event type: `:commit`, `:identity`, `:account`,
      `:handle`, `:migrate`, `:tombstone`, `:info`, `:error` or `:unknown`.
    * `:seq` - the sequence number of the event. Feed it back as the
      `:cursor` option of `ProtoRune.Firehose` to resume the stream from
      this point.
    * `:repo` - the DID of the repository the event belongs to.
    * `:time` - the event timestamp as an ISO 8601 string.
    * `:rev` - the repository revision (`:commit` events only).
    * `:ops` - the repository operations of a `:commit` event.
    * `:blocks` - the repository blocks of a `:commit` event, CBOR-decoded
      and keyed by CID string. The record for an operation can be found at
      `event.blocks[to_string(op.cid)]`.
    * `:payload` - the raw decoded frame payload, for event types without
      dedicated fields and for fields this module does not know about.
  """

  @typedoc """
  A repository operation within a `:commit` event.

    * `:action` - `:create`, `:update` or `:delete`.
    * `:path` - the record path, e.g. `"app.bsky.feed.post/3jxfb3nkkf22v"`.
    * `:cid` - the record CID (`nil` for deletions).
  """
  @type op :: %{action: :create | :update | :delete, path: String.t(), cid: ProtoRune.CID.t() | nil}

  @type t :: %__MODULE__{
          type: :commit | :identity | :account | :handle | :migrate | :tombstone | :info | :error | :unknown,
          seq: non_neg_integer | nil,
          repo: String.t() | nil,
          time: String.t() | nil,
          rev: String.t() | nil,
          ops: [op],
          blocks: %{optional(String.t()) => term},
          payload: map
        }

  defstruct [:type, :seq, :repo, :time, :rev, :payload, ops: [], blocks: %{}]

  @doc """
  Returns true when any operation of a `:commit` event belongs to the
  given collection or a collection under it.

  The match is segment-aware: `"app.bsky.feed"` matches
  `"app.bsky.feed.post"` but not `"app.bsky.feedback.x"`. Non-commit
  events carry no operations and always return false.

  ## Examples

      iex> Event.collection?(%Event{type: :commit, ops: [%{action: :create, path: "app.bsky.feed.post/abc", cid: nil}]}, "app.bsky.feed")
      true

      iex> Event.collection?(%Event{type: :commit, ops: [%{action: :create, path: "app.bsky.feedback.x/abc", cid: nil}]}, "app.bsky.feed")
      false

      iex> Event.collection?(%Event{type: :identity}, "app.bsky.feed")
      false
  """
  @spec collection?(t(), String.t()) :: boolean()
  def collection?(%__MODULE__{type: :commit, ops: ops}, prefix) when is_binary(prefix) do
    Enum.any?(ops, fn %{path: path} ->
      collection = path |> String.split("/", parts: 2) |> hd()
      collection == prefix or String.starts_with?(collection, prefix <> ".")
    end)
  end

  def collection?(%__MODULE__{}, prefix) when is_binary(prefix), do: false
end
