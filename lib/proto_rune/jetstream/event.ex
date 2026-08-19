defmodule ProtoRune.Jetstream.Event do
  @moduledoc """
  A single event decoded from a Jetstream JSON message.

  Jetstream is a JSON re-encode of the repo firehose with server-side
  filtering, so events arrive already decoded: no CAR slicing and no CBOR.
  The record of a commit operation comes inline in the message.

  ## Fields

    * `:type` - the event type: `:commit`, `:identity`, `:account` or
      `:unknown`.
    * `:did` - the DID of the repository the event belongs to.
    * `:time_us` - the event timestamp in microseconds since the Unix
      epoch. Feed it back as the `:cursor` option of
      `ProtoRune.Jetstream.start_link/1` to resume the stream.
    * `:collection` - the record collection (`:commit` events only).
    * `:rkey` - the record key (`:commit` events only).
    * `:operation` - `:create`, `:update` or `:delete` (`:commit` events
      only).
    * `:cid` - the record CID as a string (`:commit` events only, `nil`
      for deletions).
    * `:rev` - the repository revision (`:commit` events only).
    * `:record` - the decoded record for `:create` and `:update`
      operations, `nil` for deletions.
    * `:payload` - the raw decoded message, for fields this module does
      not know about.
  """

  @type operation :: :create | :update | :delete

  @type t :: %__MODULE__{
          type: :commit | :identity | :account | :unknown,
          did: String.t() | nil,
          time_us: non_neg_integer | nil,
          collection: String.t() | nil,
          rkey: String.t() | nil,
          operation: operation | nil,
          cid: String.t() | nil,
          rev: String.t() | nil,
          record: map | nil,
          payload: map
        }

  defstruct [
    :type,
    :did,
    :time_us,
    :collection,
    :rkey,
    :operation,
    :cid,
    :rev,
    :record,
    :payload
  ]

  @event_types %{"commit" => :commit, "identity" => :identity, "account" => :account}
  @operations %{"create" => :create, "update" => :update, "delete" => :delete}

  @doc """
  Builds an event from a JSON-decoded Jetstream message.
  """
  @spec from_message(map) :: {:ok, t()} | {:error, atom}
  def from_message(%{"kind" => kind} = message) do
    build(Map.get(@event_types, kind, :unknown), message)
  end

  def from_message(_other), do: {:error, :invalid_message}

  defp build(:commit, %{"commit" => commit} = message) when is_map(commit) do
    {:ok,
     %__MODULE__{
       type: :commit,
       did: message["did"],
       time_us: message["time_us"],
       rev: commit["rev"],
       collection: commit["collection"],
       rkey: commit["rkey"],
       operation: Map.get(@operations, commit["operation"]),
       cid: commit["cid"],
       record: commit["record"],
       payload: message
     }}
  end

  defp build(:commit, _message), do: {:error, :invalid_commit}

  defp build(type, message) do
    {:ok, %__MODULE__{type: type, did: message["did"], time_us: message["time_us"], payload: message}}
  end
end
