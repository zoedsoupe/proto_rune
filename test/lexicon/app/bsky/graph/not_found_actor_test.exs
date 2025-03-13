defmodule Lexicon.App.Bsky.Graph.NotFoundActorTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Graph.NotFoundActor

  describe "changeset/2" do
    test "validates required fields" do
      changeset = NotFoundActor.changeset(%NotFoundActor{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).actor

      # We set a default value for not_found, so it doesn't show up as an error
      changeset = NotFoundActor.changeset(%NotFoundActor{}, %{actor: "did:plc:123"})
      assert changeset.valid?
    end

    test "validates actor format" do
      # Valid DID
      changeset =
        NotFoundActor.changeset(%NotFoundActor{}, %{
          actor: "did:plc:1234abcd",
          not_found: true
        })

      assert changeset.valid?

      # Valid handle
      changeset =
        NotFoundActor.changeset(%NotFoundActor{}, %{
          actor: "@user.bsky.app",
          not_found: true
        })

      assert changeset.valid?

      # Invalid actor
      changeset =
        NotFoundActor.changeset(%NotFoundActor{}, %{
          actor: "invalid-actor",
          not_found: true
        })

      refute changeset.valid?
      assert "actor must be a DID or handle" in errors_on(changeset).actor
    end

    test "validates not_found is true" do
      # Valid not_found
      changeset =
        NotFoundActor.changeset(%NotFoundActor{}, %{
          actor: "did:plc:1234abcd",
          not_found: true
        })

      assert changeset.valid?

      # Invalid not_found
      changeset =
        NotFoundActor.changeset(%NotFoundActor{}, %{
          actor: "did:plc:1234abcd",
          not_found: false
        })

      refute changeset.valid?
      assert "must be true" in errors_on(changeset).not_found
    end
  end

  describe "new/1" do
    test "creates a valid not found actor" do
      actor = "did:plc:1234abcd"
      assert {:ok, not_found_actor} = NotFoundActor.new(%{actor: actor})
      assert not_found_actor.actor == actor
      assert not_found_actor.not_found == true
    end

    test "sets not_found to true by default" do
      actor = "did:plc:1234abcd"
      assert {:ok, not_found_actor} = NotFoundActor.new(%{actor: actor})
      assert not_found_actor.not_found == true
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = NotFoundActor.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid not found actor" do
      actor = "did:plc:1234abcd"
      assert %NotFoundActor{} = not_found_actor = NotFoundActor.new!(%{actor: actor})
      assert not_found_actor.actor == actor
      assert not_found_actor.not_found == true
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid not found actor/, fn ->
        NotFoundActor.new!(%{})
      end
    end
  end
end
