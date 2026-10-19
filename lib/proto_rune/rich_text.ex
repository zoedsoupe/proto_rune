defmodule ProtoRune.RichText do
  @moduledoc """
  Builder for AT Protocol rich text with facets.

  Handles byte offset calculation and facet generation for mentions, links, and hashtags.

  Facets use snake_case atom keys internally (`byte_start`, `byte_end`,
  `:"$type"`). The XRPC client camelizes them to the wire format
  (`byteStart`, `byteEnd`, `"$type"`) when posting.

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

  ## Parsing markdown-like text

  `parse/1` scans a string left to right and builds the same struct through
  the builders above, so facet indices (UTF-8 byte offsets, `byte_start`
  inclusive and `byte_end` exclusive) always match the built text:

      {:ok, rt} =
        RichText.parse("Hello @alice.test check [this](https://x.com) #elixir")

      RichText.to_plain_text(rt)
      # => "Hello @alice.test check this #elixir"

  Detection follows the official Bluesky rich text rules:

    - Links use the explicit markdown syntax `[text](url)`; the URL runs to
      the first `)`. Bare URLs are not detected.
    - A mention `@handle` is detected at the start of the text or after a
      whitespace character or an opening parenthesis. The handle is resolved
      to a DID through `ProtoRune.Atproto.Identity.resolve_handle/1`; when
      resolution fails, the mention degrades to plain text (no facet).
    - A hashtag `#tag` (ASCII or fullwidth hash) is detected at the start of
      the text or after a whitespace character, and trailing punctuation is
      stripped from the tag.

  `parse!/1` is the raising variant of `parse/1`, and the `~f` sigil is
  syntax sugar over it for literal strings:

      import ProtoRune.RichText, only: [sigil_f: 2]

      rt = ~f"Hello @alice.test #elixir"
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
          index: %{byte_start: byte_start, byte_end: byte_end},
          features: [%{"$type": "app.bsky.richtext.facet#mention", did: did}]
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
      index: %{byte_start: byte_start, byte_end: byte_end},
      features: [%{"$type": "app.bsky.richtext.facet#link", uri: url}]
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
      index: %{byte_start: byte_start, byte_end: byte_end},
      features: [%{"$type": "app.bsky.richtext.facet#tag", tag: tag}]
    }

    %{rt | text: rt.text <> tag_text, facets: rt.facets ++ [facet]}
  end

  @doc """
  Parses markdown-like text into rich text.

  Scans the string left to right, reusing `text/2`, `mention/2`, `link/3`
  and `hashtag/2` so facet byte offsets are always consistent with the
  built text. Links use the explicit markdown syntax `[text](url)`; the
  URL runs to the first `)`. Bare URLs are not detected.

  Mentions resolve the handle through `ProtoRune.Atproto.Identity.resolve_handle/1`
  and degrade to plain text when resolution fails. Hashtags strip trailing
  punctuation. Returns `{:error, :invalid_input}` for a non-binary argument.

  ## Examples

      {:ok, rt} = RichText.parse("Hello @alice.test check [this](https://x.com) #elixir")

      RichText.to_plain_text(rt)
      # => "Hello @alice.test check this #elixir"
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, :invalid_input}
  def parse(text) when is_binary(text), do: {:ok, walk(text, new())}
  def parse(_text), do: {:error, :invalid_input}

  @doc """
  Same as `parse/1` but raises `ArgumentError` on invalid input.

  ## Examples

      rt = RichText.parse!("Hello @alice.test #elixir")
  """
  @spec parse!(String.t()) :: t()
  def parse!(text) do
    case parse(text) do
      {:ok, rt} -> rt
      {:error, :invalid_input} -> raise ArgumentError, "invalid rich text input, expected a string, got: #{inspect(text)}"
    end
  end

  @doc """
  Parses a literal string at runtime through `parse!/1`, yielding a
  `%ProtoRune.RichText{}`.

      import ProtoRune.RichText, only: [sigil_f: 2]

      rt = ~f"Hello @alice.test #elixir"

  Only literal (non-interpolated) strings are supported, and no modifiers;
  for dynamic text call `parse!/1` on the built string instead.
  """
  defmacro sigil_f({:<<>>, _meta, [text]}, []) when is_binary(text) do
    quote(do: ProtoRune.RichText.parse!(unquote(text)))
  end

  defmacro sigil_f({:<<>>, _meta, [text]}, _modifiers) when is_binary(text) do
    raise ArgumentError, "the ~f sigil does not support modifiers; use plain ~f\"...\" or ProtoRune.RichText.parse!/1"
  end

  defmacro sigil_f({:<<>>, _meta, _parts}, _modifiers) do
    raise ArgumentError,
          "the ~f sigil does not support interpolation; call ProtoRune.RichText.parse!/1 on the built string instead"
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

  # -- Parsing --

  # Official detection rules: a mention may follow a whitespace character or
  # an opening parenthesis; a hashtag may only follow whitespace.
  @mention_boundary ~r/[\s(]/u
  @hashtag_boundary ~r/\s/u
  @non_whitespace_run ~r/^\S+/u
  @trailing_punctuation ~r/\p{P}+$/u

  # Walks the input one token at a time (a link, a mention, a hashtag or a
  # single character of plain text), reusing the builders so facet byte
  # offsets stay consistent with the text built so far.
  defp walk("", rt), do: rt

  defp walk(string, rt) do
    {rt, rest} = consume_token(string, rt)
    walk(rest, rt)
  end

  # A "[" only opens a link when the full markdown shape is present,
  # otherwise it degrades to plain text.
  defp consume_token(<<?[, _::binary>> = string, rt) do
    case match_link(string) do
      {link_text, url, rest} -> {link(rt, link_text, url), rest}
      :nomatch -> consume_char(string, rt)
    end
  end

  defp consume_token(string, rt) do
    if boundary?(rt.text, :mention) do
      case match_mention(string) do
        {handle, suffix, rest} -> {rt |> mention(handle) |> text(suffix), rest}
        :nomatch -> consume_non_link(string, rt)
      end
    else
      consume_non_link(string, rt)
    end
  end

  defp consume_non_link(string, rt) do
    if boundary?(rt.text, :hashtag) do
      case match_hashtag(string) do
        {tag, suffix, rest} -> {rt |> hashtag(tag) |> text(suffix), rest}
        :nomatch -> consume_char(string, rt)
      end
    else
      consume_char(string, rt)
    end
  end

  # Plain text: consume one character. Invalid UTF-8 bytes have no facet
  # semantics and are kept byte by byte.
  defp consume_char(<<char::utf8, rest::binary>>, rt), do: {text(rt, <<char::utf8>>), rest}
  defp consume_char(<<byte, rest::binary>>, rt), do: {text(rt, <<byte>>), rest}

  # A mention or hashtag may start the text or follow the characters
  # allowed by its detection rule.
  defp boundary?("", _kind), do: true
  defp boundary?(text, :mention), do: String.match?(String.last(text), @mention_boundary)
  defp boundary?(text, :hashtag), do: String.match?(String.last(text), @hashtag_boundary)

  # Matches "[link text](url)", with the URL running to the first ")".
  defp match_link(<<?[, rest::binary>>) do
    with [link_text, <<?(, url_and_rest::binary>>] <- :binary.split(rest, "]"),
         [url, after_url] <- :binary.split(url_and_rest, ")") do
      {link_text, url, after_url}
    else
      _ -> :nomatch
    end
  end

  defp match_link(_string), do: :nomatch

  # Matches "@handle", where the handle is a run of [a-zA-Z0-9.-]. One
  # trailing dot is sentence punctuation, not part of the handle.
  defp match_mention(<<?@, rest::binary>>) do
    {run, after_run} = take_handle_run(rest)

    case split_handle(run) do
      {:ok, handle, suffix} -> {handle, suffix, after_run}
      :error -> :nomatch
    end
  end

  defp match_mention(_string), do: :nomatch

  # Strips one trailing dot from the handle run (sentence punctuation).
  # Returns the handle and the stripped suffix, or :error when nothing
  # usable is left (empty run, or the run is just a dot).
  defp split_handle(""), do: :error

  defp split_handle(run) do
    last = byte_size(run) - 1

    if binary_part(run, last, 1) == "." do
      case binary_part(run, 0, last) do
        "" -> :error
        handle -> {:ok, handle, "."}
      end
    else
      {:ok, run, ""}
    end
  end

  defguardp is_handle_char(char)
            when char in ?a..?z or char in ?A..?Z or char in ?0..?9 or char in [?., ?-]

  # Splits off the leading run of handle characters (ASCII only).
  defp take_handle_run(string), do: take_handle_run(string, "")

  defp take_handle_run(<<char, rest::binary>>, acc) when is_handle_char(char) do
    take_handle_run(rest, <<acc::binary, char>>)
  end

  defp take_handle_run(string, acc), do: {acc, string}

  # Matches "#tag" (ASCII or fullwidth hash), where the tag is the run of
  # non-whitespace characters after the hash. Trailing punctuation is not
  # part of the tag; a tag that becomes empty after stripping is skipped.
  defp match_hashtag(<<?#, rest::binary>>), do: match_tag(rest)
  defp match_hashtag("＃" <> rest), do: match_tag(rest)
  defp match_hashtag(_string), do: :nomatch

  defp match_tag(rest) do
    case Regex.run(@non_whitespace_run, rest) do
      [tag_run] ->
        tag = Regex.replace(@trailing_punctuation, tag_run, "")

        if tag == "" do
          :nomatch
        else
          suffix = binary_part(tag_run, byte_size(tag), byte_size(tag_run) - byte_size(tag))
          after_run = binary_part(rest, byte_size(tag_run), byte_size(rest) - byte_size(tag_run))
          {tag, suffix, after_run}
        end

      nil ->
        :nomatch
    end
  end
end
