defmodule ProtoRune.RichTextTest do
  use ExUnit.Case, async: false

  import ProtoRune.RichText, only: [sigil_f: 2]

  alias ProtoRune.RichText

  describe "parse/1" do
    test "plain text builds no facets" do
      assert {:ok, %RichText{text: "just plain text", facets: []}} = RichText.parse("just plain text")
      assert {:ok, %RichText{text: "", facets: []}} = RichText.parse("")
    end

    test "markdown link" do
      {:ok, rt} = RichText.parse("check [this](https://x.com) out")

      assert rt.text == "check this out"
      assert [%{index: %{byte_start: 6, byte_end: 10}, features: [feature]}] = rt.facets
      assert feature == %{"$type": "app.bsky.richtext.facet#link", uri: "https://x.com"}
    end

    test "hashtag" do
      {:ok, rt} = RichText.parse("hello #elixir")

      assert rt.text == "hello #elixir"

      assert [
               %{
                 index: %{byte_start: 6, byte_end: 13},
                 features: [%{"$type": "app.bsky.richtext.facet#tag", tag: "elixir"}]
               }
             ] = rt.facets
    end

    test "mention resolves the handle from the identity cache" do
      start_cache()

      {:ok, rt} = RichText.parse("hi @alice.test!")

      assert rt.text == "hi @alice.test!"

      assert [
               %{
                 index: %{byte_start: 3, byte_end: 14},
                 features: [%{"$type": "app.bsky.richtext.facet#mention", did: "did:plc:alice"}]
               }
             ] = rt.facets
    end

    test "mention that fails to resolve degrades to plain text" do
      {:ok, rt} = RichText.parse("hi @bob.123!")

      assert rt.text == "hi @bob.123!"
      assert rt.facets == []
    end

    test "mixed text" do
      start_cache()

      {:ok, rt} = RichText.parse("Hello @alice.test check [this](https://x.com) #elixir")

      assert rt.text == "Hello @alice.test check this #elixir"

      assert [
               %{index: %{byte_start: 6, byte_end: 17}, features: [mention]},
               %{index: %{byte_start: 24, byte_end: 28}, features: [link]},
               %{index: %{byte_start: 29, byte_end: 36}, features: [tag]}
             ] = rt.facets

      assert mention == %{"$type": "app.bsky.richtext.facet#mention", did: "did:plc:alice"}
      assert link == %{"$type": "app.bsky.richtext.facet#link", uri: "https://x.com"}
      assert tag == %{"$type": "app.bsky.richtext.facet#tag", tag: "elixir"}
    end

    test "byte offsets count UTF-8 bytes, not characters" do
      {:ok, rt} = RichText.parse("日本語 #elixir")
      assert [%{index: %{byte_start: 10, byte_end: 17}}] = rt.facets

      {:ok, rt} = RichText.parse("🎉🎉 [link](https://x.com)")
      assert [%{index: %{byte_start: 9, byte_end: 13}}] = rt.facets
    end

    test "strips trailing punctuation from a hashtag" do
      {:ok, rt} = RichText.parse("wow #elixir.")

      assert rt.text == "wow #elixir."

      assert [
               %{
                 index: %{byte_start: 4, byte_end: 11},
                 features: [%{"$type": "app.bsky.richtext.facet#tag", tag: "elixir"}]
               }
             ] = rt.facets
    end

    test "strips one trailing dot from a mention" do
      start_cache()

      {:ok, rt} = RichText.parse("hi @alice.test.")

      assert rt.text == "hi @alice.test."

      assert [
               %{
                 index: %{byte_start: 3, byte_end: 14},
                 features: [%{"$type": "app.bsky.richtext.facet#mention", did: "did:plc:alice"}]
               }
             ] = rt.facets
    end

    test "skips empty tags" do
      {:ok, rt} = RichText.parse("tags: # #. #elixir")

      assert rt.text == "tags: # #. #elixir"
      assert [%{features: [%{"$type": "app.bsky.richtext.facet#tag", tag: "elixir"}]}] = rt.facets
    end

    test "returns {:error, :invalid_input} for non-binary input" do
      assert RichText.parse(nil) == {:error, :invalid_input}
      assert RichText.parse(42) == {:error, :invalid_input}
      assert RichText.parse(:hello) == {:error, :invalid_input}
      assert RichText.parse(["hello"]) == {:error, :invalid_input}
    end
  end

  describe "parse!/1" do
    test "returns the rich text for valid input" do
      assert %RichText{text: "hi #elixir", facets: [facet]} = RichText.parse!("hi #elixir")
      assert %{index: %{byte_start: 3, byte_end: 10}} = facet
    end

    test "raises ArgumentError on non-binary input" do
      assert_raise ArgumentError, fn -> RichText.parse!(nil) end
      assert_raise ArgumentError, fn -> RichText.parse!(42) end
    end
  end

  describe "~f sigil" do
    test "expands to a parsed RichText struct" do
      rt = ~f"Hello #elixir [docs](https://atproto.com)"

      assert %RichText{} = rt
      assert rt.text == "Hello #elixir docs"
      assert length(rt.facets) == 2
    end

    test "raises a compile error on interpolation" do
      assert_raise ArgumentError, ~r/interpolation/, fn ->
        Code.eval_string(~S"""
        import ProtoRune.RichText, only: [sigil_f: 2]
        handle = "alice.test"
        ~f"hi @#{handle}"
        """)
      end
    end

    test "raises a compile error on modifiers" do
      assert_raise ArgumentError, ~r/modifier/, fn ->
        Code.eval_string(~S"""
        import ProtoRune.RichText, only: [sigil_f: 2]
        ~f"hi #elixir"a
        """)
      end
    end
  end

  # Starts the identity cache and seeds the handle -> DID entry the mention
  # tests rely on, so resolution stays deterministic (no network). The table
  # shape mirrors ProtoRune.Atproto.Identity.Cache (compare oauth_test.exs).
  defp start_cache do
    start_supervised!(ProtoRune.Atproto.Identity.Cache)

    expires_at = System.system_time(:millisecond) + 60_000
    :ets.insert(:handle_cache, {"alice.test", "did:plc:alice", %{expires_at: expires_at}})
  end
end
