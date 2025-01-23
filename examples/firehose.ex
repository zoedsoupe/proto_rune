# examples/firehose.ex
defmodule ExampleFirehose do
  use ProtoRune.Firehose, cursor: "latest", relay: "wss://bsky.network"

  subscribe_for ["app.bsky.feed.post", "app.bsky.feed.like"]

  @impl true
  def handle_event(%Firehose.Event{type: "app.bsky.feed.post"} = event) do
    # Process new post
    Logger.info("New post from #{event.author}: #{event.record.text}")
  end

  def handle_event(%Firehose.Event{type: "app.bsky.feed.like"} = event) do
    # Process new like
    Logger.info("#{event.author} liked post #{event.subject.uri}")
  end
end
