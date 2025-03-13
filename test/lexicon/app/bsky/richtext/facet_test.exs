defmodule Lexicon.App.Bsky.Richtext.FacetTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Richtext.ByteSlice
  alias Lexicon.App.Bsky.Richtext.Facet

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Facet.changeset(%Facet{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).index
      assert "can't be blank" in errors_on(changeset).features
    end

    test "validates index" do
      # Invalid index
      changeset =
        Facet.changeset(%Facet{}, %{
          features: [%{did: "did:plc:1234abcd"}],
          index: %{byte_start: -1, byte_end: 5}
        })

      refute changeset.valid?
      assert errors_on(changeset).index != %{}
    end

    test "validates features with mention" do
      # Valid mention feature
      changeset =
        Facet.changeset(%Facet{}, %{
          index: %{byte_start: 0, byte_end: 10},
          features: [%{did: "did:plc:1234abcd"}]
        })

      assert changeset.valid?

      # Invalid mention feature
      changeset =
        Facet.changeset(%Facet{}, %{
          index: %{byte_start: 0, byte_end: 10},
          features: [%{did: "invalid-did"}]
        })

      refute changeset.valid?
      assert "must be a list of valid features (mention, link, or tag)" in errors_on(changeset).features
    end

    test "validates features with link" do
      # Valid link feature
      changeset =
        Facet.changeset(%Facet{}, %{
          index: %{byte_start: 0, byte_end: 10},
          features: [%{uri: "https://example.com"}]
        })

      assert changeset.valid?

      # Invalid link feature
      changeset =
        Facet.changeset(%Facet{}, %{
          index: %{byte_start: 0, byte_end: 10},
          features: [%{uri: "invalid-uri"}]
        })

      refute changeset.valid?
      assert "must be a list of valid features (mention, link, or tag)" in errors_on(changeset).features
    end

    test "validates features with tag" do
      # Valid tag feature
      changeset =
        Facet.changeset(%Facet{}, %{
          index: %{byte_start: 0, byte_end: 10},
          features: [%{tag: "bluesky"}]
        })

      assert changeset.valid?

      # Invalid tag feature (too long)
      changeset =
        Facet.changeset(%Facet{}, %{
          index: %{byte_start: 0, byte_end: 10},
          features: [%{tag: String.duplicate("x", 641)}]
        })

      refute changeset.valid?
      assert "must be a list of valid features (mention, link, or tag)" in errors_on(changeset).features
    end

    test "validates mixed features" do
      # Multiple valid features
      changeset =
        Facet.changeset(%Facet{}, %{
          index: %{byte_start: 0, byte_end: 10},
          features: [
            %{did: "did:plc:1234abcd"},
            %{uri: "https://example.com"},
            %{tag: "bluesky"}
          ]
        })

      assert changeset.valid?

      # Invalid - features is not a list
      changeset =
        Facet.changeset(%Facet{}, %{
          index: %{byte_start: 0, byte_end: 10},
          features: "not-a-list"
        })

      refute changeset.valid?
      assert "must be a list of valid features (mention, link, or tag)" in errors_on(changeset).features

      # Invalid - unrecognized feature type
      changeset =
        Facet.changeset(%Facet{}, %{
          index: %{byte_start: 0, byte_end: 10},
          features: [%{unknown: "feature"}]
        })

      refute changeset.valid?
      assert "must be a list of valid features (mention, link, or tag)" in errors_on(changeset).features
    end
  end

  describe "new/1" do
    test "creates a valid facet with mention" do
      attrs = %{
        index: %{byte_start: 0, byte_end: 10},
        features: [%{did: "did:plc:1234abcd"}]
      }

      assert {:ok, facet} = Facet.new(attrs)
      assert %ByteSlice{byte_start: 0, byte_end: 10} = facet.index
      assert [%{did: "did:plc:1234abcd"}] = facet.features
    end

    test "creates a valid facet with multiple features" do
      attrs = %{
        index: %{byte_start: 0, byte_end: 10},
        features: [
          %{did: "did:plc:1234abcd"},
          %{uri: "https://example.com"},
          %{tag: "bluesky"}
        ]
      }

      assert {:ok, facet} = Facet.new(attrs)
      assert %ByteSlice{byte_start: 0, byte_end: 10} = facet.index
      assert 3 = length(facet.features)
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = Facet.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid facet" do
      attrs = %{
        index: %{byte_start: 0, byte_end: 10},
        features: [%{did: "did:plc:1234abcd"}]
      }

      assert %Facet{} = facet = Facet.new!(attrs)
      assert %ByteSlice{} = facet.index
      assert 1 = length(facet.features)
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid facet/, fn ->
        Facet.new!(%{})
      end
    end
  end
end
