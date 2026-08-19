defmodule ProtoRune.Jetstream.EventTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Jetstream.Event

  test "decodes a commit create event with the inline record" do
    message = %{
      "kind" => "commit",
      "did" => "did:plc:abc",
      "time_us" => 1_725_516_133_891_108,
      "commit" => %{
        "rev" => "3l3qo2vutsw2b",
        "operation" => "create",
        "collection" => "place.quintal.feed.prosa",
        "rkey" => "3l3qo2vutsw2b",
        "cid" => "bafyreid",
        "record" => %{"$type" => "place.quintal.feed.prosa", "texto" => "oi"}
      }
    }

    assert {:ok,
            %Event{
              type: :commit,
              did: "did:plc:abc",
              time_us: 1_725_516_133_891_108,
              collection: "place.quintal.feed.prosa",
              rkey: "3l3qo2vutsw2b",
              operation: :create,
              cid: "bafyreid",
              rev: "3l3qo2vutsw2b",
              record: %{"texto" => "oi"},
              payload: ^message
            }} = Event.from_message(message)
  end

  test "decodes a commit delete event without cid or record" do
    message = %{
      "kind" => "commit",
      "did" => "did:plc:abc",
      "time_us" => 1,
      "commit" => %{
        "rev" => "3l3qo2vutsw2b",
        "operation" => "delete",
        "collection" => "place.quintal.feed.prosa",
        "rkey" => "3l3qo2vutsw2b"
      }
    }

    assert {:ok, %Event{type: :commit, operation: :delete, cid: nil, record: nil}} =
             Event.from_message(message)
  end

  test "decodes identity and account events" do
    assert {:ok, %Event{type: :identity, did: "did:plc:abc", time_us: 7}} =
             Event.from_message(%{"kind" => "identity", "did" => "did:plc:abc", "time_us" => 7})

    assert {:ok, %Event{type: :account, did: "did:plc:abc", time_us: 8}} =
             Event.from_message(%{"kind" => "account", "did" => "did:plc:abc", "time_us" => 8})
  end

  test "maps unknown kinds to :unknown" do
    assert {:ok, %Event{type: :unknown}} = Event.from_message(%{"kind" => "future_kind"})
  end

  test "rejects messages without a kind and commits without a commit object" do
    assert {:error, :invalid_message} = Event.from_message(%{"did" => "did:plc:abc"})
    assert {:error, :invalid_commit} = Event.from_message(%{"kind" => "commit"})
  end
end
