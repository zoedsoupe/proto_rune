defmodule ProtoRune.Atproto do
  @moduledoc """
  AT Protocol utilities.
  """

  @doc """
  Parses an AT-URI into its `{repo, collection, rkey}` parts.

      iex> ProtoRune.Atproto.parse_at_uri("at://did:plc:abc/app.bsky.feed.post/3kxyz")
      {:ok, {"did:plc:abc", "app.bsky.feed.post", "3kxyz"}}

      iex> ProtoRune.Atproto.parse_at_uri("https://example.com")
      {:error, :invalid_at_uri}
  """
  @spec parse_at_uri(String.t()) :: {:ok, {String.t(), String.t(), String.t()}} | {:error, :invalid_at_uri}
  def parse_at_uri("at://" <> rest) do
    case String.split(rest, "/", parts: 3) do
      [repo, collection, rkey] -> {:ok, {repo, collection, rkey}}
      _ -> {:error, :invalid_at_uri}
    end
  end

  def parse_at_uri(_), do: {:error, :invalid_at_uri}
end
