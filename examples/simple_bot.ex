# examples/simple_bot.ex
defmodule ExampleBot do
 use ProtoRune.Bot,
   name: :example_bot,
   strategy: :polling,
   service: "https://bsky.social"

  require Logger

 @impl true
 def get_identifier, do: System.get_env("BSKY_IDENTIFIER") 
 def get_password, do: System.get_env("BSKY_APP_PASSWORD")

 @impl true
 def handle_event(:like, %{uri: uri, user: user}) do
   Logger.info("Got like from #{user.handle} on #{uri}")
 end

 def handle_event(:reply, %{post: post, user: user}) do
   text = "Thanks for your reply, #{user.handle}!"
   ProtoRune.create_post(post.uri, text)
 end

 def handle_event(:follow, %{user: user}) do
   Logger.info("New follower: #{user.handle}")
   ProtoRune.follow(user.did)
 end
end
