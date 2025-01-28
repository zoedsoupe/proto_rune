defmodule ProtoRune.Atproto do
  @moduledoc false

  def parse_at_uri(<<"at://"::utf8, did::binary-size(32), "/"::utf8, rest::binary>>) do
    case rest do
      "app.bsky.feed.post" <> _ -> {:ok, {did, :post}}
      "app.bsky.feed.generator" <> _ -> {:ok, {did, :generator}}
      "app.bsky.labeler.service" <> _ -> {:ok, {did, :service}}
    end
  end

  def parse_at_uri(_), do: {:error, :invalid_uri}
end
