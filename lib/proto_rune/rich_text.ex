defmodule ProtoRune.RichText do
  @moduledoc """
  Builder for AT Protocol rich text with facets.

  Handles byte offset calculation and facet generation for mentions, links, and hashtags.

  ## Examples

      # Build rich text with mentions and links
      {:ok, rt} =
        RichText.new()
        |> RichText.text("Hello ")
        |> RichText.mention("alice.bsky.social")
        |> RichText.text("! Check out ")
        |> RichText.link("this project", "https://example.com")
        |> RichText.text(" ")
        |> RichText.hashtag("elixir")
        |> RichText.build()

      # Use in post
      {:ok, post} = ProtoRune.Bsky.post(session, rt)

      # Get plain text
      plain = RichText.to_plain_text(rt)
      # => "Hello @alice.bsky.social! Check out this project #elixir"
  """

  alias ProtoRune.Atproto.Identity

  defstruct text: "", facets: []

  @type t :: %__MODULE__{
          text: String.t(),
          facets: [map()]
        }

  @doc """
  Creates a new rich text builder.

  ## Examples

      rt = RichText.new()
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Appends plain text to the builder.

  ## Examples

      rt = RichText.new() |> RichText.text("Hello world")
  """
  @spec text(t(), String.t()) :: t()
  def text(%__MODULE__{} = rt, content) when is_binary(content) do
    %{rt | text: rt.text <> content}
  end

  @doc """
  Appends a mention to the builder.

  The mention will be formatted as `@handle` in the text. If DID resolution
  succeeds, a mention facet will be created. If resolution fails, the text
  is added without a facet (plain text mention).

  ## Examples

      rt = RichText.new() |> RichText.mention("alice.bsky.social")
      # => "@alice.bsky.social" in text with mention facet (if DID resolves)
  """
  @spec mention(t(), String.t()) :: t()
  def mention(%__MODULE__{} = rt, handle) when is_binary(handle) do
    byte_start = byte_size(rt.text)
    mention_text = "@#{handle}"
    byte_end = byte_start + byte_size(mention_text)

    # Resolve handle to DID (with caching)
    case Identity.resolve_handle(handle) do
      {:ok, did} ->
        facet = %{
          index: %{
            byteStart: byte_start,
            byteEnd: byte_end
          },
          features: [
            %{
              "$type" => "app.bsky.richtext.facet#mention",
              did: did
            }
          ]
        }

        %{rt | text: rt.text <> mention_text, facets: rt.facets ++ [facet]}

      {:error, _reason} ->
        # Resolution failed, just add plain text without facet
        %{rt | text: rt.text <> mention_text}
    end
  end

  @doc """
  Appends a link to the builder.

  The link text will appear in the final text, and a facet will be created
  pointing to the URL.

  ## Examples

      rt = RichText.new() |> RichText.link("click here", "https://example.com")
  """
  @spec link(t(), String.t(), String.t()) :: t()
  def link(%__MODULE__{} = rt, link_text, url) when is_binary(link_text) and is_binary(url) do
    byte_start = byte_size(rt.text)
    byte_end = byte_start + byte_size(link_text)

    facet = %{
      index: %{
        byteStart: byte_start,
        byteEnd: byte_end
      },
      features: [
        %{
          "$type" => "app.bsky.richtext.facet#link",
          uri: url
        }
      ]
    }

    %{rt | text: rt.text <> link_text, facets: rt.facets ++ [facet]}
  end

  @doc """
  Appends a hashtag to the builder.

  The hashtag will be formatted as `#tag` in the text, and a facet will be created.

  ## Examples

      rt = RichText.new() |> RichText.hashtag("elixir")
      # => "#elixir" in text with tag facet
  """
  @spec hashtag(t(), String.t()) :: t()
  def hashtag(%__MODULE__{} = rt, tag) when is_binary(tag) do
    byte_start = byte_size(rt.text)
    tag_text = "##{tag}"
    byte_end = byte_start + byte_size(tag_text)

    facet = %{
      index: %{
        byteStart: byte_start,
        byteEnd: byte_end
      },
      features: [
        %{
          "$type" => "app.bsky.richtext.facet#tag",
          tag: tag
        }
      ]
    }

    %{rt | text: rt.text <> tag_text, facets: rt.facets ++ [facet]}
  end

  @doc """
  Builds the rich text, returning a map suitable for use in posts.

  ## Examples

      {:ok, post_data} =
        RichText.new()
        |> RichText.text("Hello ")
        |> RichText.mention("alice.bsky.social")
        |> RichText.build()

      # Use with Bsky.post
      {:ok, post} = ProtoRune.Bsky.post(session, post_data)
  """
  @spec build(t()) :: {:ok, map()}
  def build(%__MODULE__{} = rt) do
    post_data = %{
      text: rt.text,
      facets: rt.facets
    }

    {:ok, post_data}
  end

  @doc """
  Converts rich text back to plain text.

  ## Examples

      plain = RichText.to_plain_text(rt)
  """
  @spec to_plain_text(t() | map()) :: String.t()
  def to_plain_text(%__MODULE__{text: text}), do: text
  def to_plain_text(%{text: text}) when is_binary(text), do: text
  def to_plain_text(_), do: ""

  @doc """
  Gets the facets from rich text.

  ## Examples

      facets = RichText.facets(rt)
  """
  @spec facets(t() | map()) :: [map()]
  def facets(%__MODULE__{facets: facets}), do: facets
  def facets(%{facets: facets}) when is_list(facets), do: facets
  def facets(_), do: []
end
