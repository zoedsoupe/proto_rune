defmodule ProtoRune.Bsky.Embed do
  @moduledoc """
  Builders for `app.bsky.embed.*` post embeds.

  Pure functions returning plain maps in record shape: snake_case atom
  keys, camelized on the wire by the XRPC layer. Pass the result to
  `ProtoRune.Bsky.post/3` via the `:embed` option.

  Images, videos and external-card thumbs are blob references as
  returned by `ProtoRune.Atproto.Repo.upload_blob/3` - the upload is
  the caller's (imperative) step. `ProtoRune.Bsky.post/3` also accepts
  raw image data via `:images` and raw video data via `:video` and
  uploads for you.

  ## Examples

      {:ok, %{blob: blob}} = Repo.upload_blob(session, png, "image/png")

      embed = Embed.images([%{alt: "a cat", image: blob}])
      {:ok, post} = Bsky.post(session, "cat", embed: embed)

      {:ok, post} = Bsky.post(session, "link", embed: Embed.external(url, "Title", "Desc"))

      {:ok, post} = Bsky.post(session, "quote", embed: Embed.record(uri, cid))
  """

  @typedoc "A blob reference map as returned by `Repo.upload_blob/3`."
  @type blob :: map()

  @typedoc "An embed map ready to put in an `app.bsky.feed.post` record."
  @type embed :: map()

  @doc """
  Builds an `app.bsky.embed.images` embed.

  Each entry is a map with `:alt` (string, may be empty) and `:image`
  (a blob reference). `:aspect_ratio` (`%{width: w, height: h}`) is
  optional. At most 4 images per post.
  """
  @spec images([%{:alt => String.t(), :image => blob(), optional(:aspect_ratio) => map()}]) :: embed()
  def images(images) when is_list(images) and length(images) in 1..4 do
    %{:"$type" => "app.bsky.embed.images", images: Enum.map(images, &image/1)}
  end

  defp image(%{alt: alt, image: blob} = entry) do
    base = %{alt: alt, image: blob}

    case Map.get(entry, :aspect_ratio) do
      nil -> base
      ratio -> Map.put(base, :aspect_ratio, ratio)
    end
  end

  @doc """
  Builds an `app.bsky.embed.video` embed.

  `video` is a blob reference for the mp4 file, as returned by
  `ProtoRune.Atproto.Repo.upload_blob/3`. `ProtoRune.Bsky.post/3` also
  accepts raw video data via the `:video` option and uploads it for you.

  ## Options

    * `:alt` - alt text description of the video (string)
    * `:aspect_ratio` - `%{width: w, height: h}`
    * `:captions` - list of caption entries, each a map with `:lang`
      (a language code) and `:file` (a `text/vtt` blob reference).
      At most 20 per video.
  """
  @spec video(blob(), keyword()) :: embed()
  def video(video, opts \\ []) when is_map(video) do
    %{:"$type" => "app.bsky.embed.video", video: video}
    |> put_opt(:alt, Keyword.get(opts, :alt))
    |> put_opt(:aspect_ratio, Keyword.get(opts, :aspect_ratio))
    |> put_opt(:captions, Keyword.get(opts, :captions))
  end

  @doc """
  Builds an `app.bsky.embed.external` embed (a link card).

  `thumb` is an optional blob reference for the card image.
  """
  @spec external(String.t(), String.t(), String.t(), blob() | nil) :: embed()
  def external(uri, title, description, thumb \\ nil)
      when is_binary(uri) and is_binary(title) and is_binary(description) do
    card = %{uri: uri, title: title, description: description}
    card = if thumb, do: Map.put(card, :thumb, thumb), else: card
    %{:"$type" => "app.bsky.embed.external", external: card}
  end

  @doc """
  Builds an `app.bsky.embed.record` embed (a quote post) from the quoted
  post's AT-URI and CID.
  """
  @spec record(String.t(), String.t()) :: embed()
  def record(uri, cid) when is_binary(uri) and is_binary(cid) do
    %{:"$type" => "app.bsky.embed.record", record: %{uri: uri, cid: cid}}
  end

  @doc """
  Builds an `app.bsky.embed.recordWithMedia` embed: a quote post combined
  with an `images/1`, `video/2` or `external/4` media embed.
  """
  @spec record_with_media(embed(), embed()) :: embed()
  def record_with_media(%{:"$type" => "app.bsky.embed.record"} = record, %{:"$type" => media_type} = media)
      when media_type in ["app.bsky.embed.images", "app.bsky.embed.video", "app.bsky.embed.external"] do
    %{:"$type" => "app.bsky.embed.recordWithMedia", record: record, media: media}
  end

  defp put_opt(map, _key, nil), do: map
  defp put_opt(map, key, value), do: Map.put(map, key, value)
end
