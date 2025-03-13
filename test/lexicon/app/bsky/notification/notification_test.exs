defmodule Lexicon.App.Bsky.Notification.NotificationTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Notification.Notification

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Notification.changeset(%Notification{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).uri
      assert "can't be blank" in errors_on(changeset).cid
      assert "can't be blank" in errors_on(changeset).author
      assert "can't be blank" in errors_on(changeset).reason
      assert "can't be blank" in errors_on(changeset).record
      assert "can't be blank" in errors_on(changeset).is_read
      assert "can't be blank" in errors_on(changeset).indexed_at
    end

    test "validates uri format" do
      # Valid URI
      valid_attrs = %{
        uri: "at://did:plc:1234/app.bsky.feed.post/1",
        cid: "bafyreiabc123",
        author: %{did: "did:plc:1234", handle: "user.bsky.app"},
        reason: "like",
        record: %{type: "like"},
        is_read: false,
        indexed_at: DateTime.utc_now()
      }

      changeset = Notification.changeset(%Notification{}, valid_attrs)
      assert changeset.valid?

      # Invalid URI
      changeset = Notification.changeset(%Notification{}, %{valid_attrs | uri: "invalid-uri"})
      refute changeset.valid?
      assert "must be a valid AT-URI" in errors_on(changeset).uri
    end

    test "validates reason" do
      valid_attrs = %{
        uri: "at://did:plc:1234/app.bsky.feed.post/1",
        cid: "bafyreiabc123",
        author: %{did: "did:plc:1234", handle: "user.bsky.app"},
        record: %{type: "like"},
        is_read: false,
        indexed_at: DateTime.utc_now()
      }

      # Valid reasons
      for reason <- ~w(like repost follow mention reply quote starterpack-joined) do
        changeset =
          Notification.changeset(
            %Notification{},
            Map.put(valid_attrs, :reason, reason)
          )

        assert changeset.valid?
      end

      # Invalid reason
      changeset =
        Notification.changeset(
          %Notification{},
          Map.put(valid_attrs, :reason, "invalid-reason")
        )

      refute changeset.valid?

      assert "must be one of: like, repost, follow, mention, reply, quote, starterpack-joined" in errors_on(changeset).reason
    end

    test "validates optional reason_subject" do
      valid_attrs = %{
        uri: "at://did:plc:1234/app.bsky.feed.post/1",
        cid: "bafyreiabc123",
        author: %{did: "did:plc:1234", handle: "user.bsky.app"},
        reason: "like",
        record: %{type: "like"},
        is_read: false,
        indexed_at: DateTime.utc_now()
      }

      # Valid reason_subject
      changeset =
        Notification.changeset(
          %Notification{},
          Map.put(valid_attrs, :reason_subject, "at://did:plc:5678/app.bsky.feed.post/2")
        )

      assert changeset.valid?

      # Invalid reason_subject
      changeset =
        Notification.changeset(
          %Notification{},
          Map.put(valid_attrs, :reason_subject, "invalid-uri")
        )

      refute changeset.valid?
      assert "must be a valid AT-URI" in errors_on(changeset).reason_subject

      # Nil reason_subject is valid
      changeset =
        Notification.changeset(
          %Notification{},
          Map.put(valid_attrs, :reason_subject, nil)
        )

      assert changeset.valid?
    end
  end

  describe "new/1" do
    test "creates a valid notification" do
      now = DateTime.truncate(DateTime.utc_now(), :second)

      attrs = %{
        uri: "at://did:plc:1234/app.bsky.feed.post/1",
        cid: "bafyreiabc123",
        author: %{did: "did:plc:1234", handle: "user.bsky.app"},
        reason: "like",
        record: %{type: "like"},
        is_read: false,
        indexed_at: now
      }

      assert {:ok, notification} = Notification.new(attrs)
      assert notification.uri == attrs.uri
      assert notification.cid == attrs.cid
      assert notification.author == attrs.author
      assert notification.reason == attrs.reason
      assert notification.record == attrs.record
      assert notification.is_read == attrs.is_read
      assert notification.indexed_at == now
      assert notification.reason_subject == nil
      assert notification.labels == nil
    end

    test "creates a notification with optional fields" do
      now = DateTime.truncate(DateTime.utc_now(), :second)

      attrs = %{
        uri: "at://did:plc:1234/app.bsky.feed.post/1",
        cid: "bafyreiabc123",
        author: %{did: "did:plc:1234", handle: "user.bsky.app"},
        reason: "like",
        reason_subject: "at://did:plc:5678/app.bsky.feed.post/2",
        record: %{type: "like"},
        is_read: false,
        indexed_at: now,
        labels: [%{val: "spam"}]
      }

      assert {:ok, notification} = Notification.new(attrs)
      assert notification.reason_subject == attrs.reason_subject
      assert notification.labels == attrs.labels
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = Notification.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid notification" do
      attrs = %{
        uri: "at://did:plc:1234/app.bsky.feed.post/1",
        cid: "bafyreiabc123",
        author: %{did: "did:plc:1234", handle: "user.bsky.app"},
        reason: "like",
        record: %{type: "like"},
        is_read: false,
        indexed_at: DateTime.utc_now()
      }

      assert %Notification{} = notification = Notification.new!(attrs)
      assert notification.uri == attrs.uri
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid notification/, fn ->
        Notification.new!(%{})
      end
    end
  end
end
