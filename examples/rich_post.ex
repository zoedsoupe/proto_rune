# examples/rich_post.ex
defmodule ExamplePost do
 import ProtoRune.RichText

 alias ProtoRune.RichText

 def create_post_with_image(session) do
   # Parse rich text directly using sigil
   # f stands for `facet`
   text = ~f"""
   Check out @alice.bsky.social's new [project](https://example.com)! 
   Some *bold text* with a _link_ and #hashtag
   """ 

   # or using more explicit pipeline
   text = RichText.new()
     |> RichText.text("Check out ")
     |> RichText.mention("alice.bsky.social")
     |> RichText.text("'s new ")
     |> RichText.link("project", "https://example.com")
     |> RichText.text("!")

   {:ok, blob} = ProtoRune.upload_blob(session, path: "cat.jpeg")

   # Both approaches work identically with post creation
   ProtoRune.create_post(session, 
     text: text,
     embed: %{
       image: blob,
       alt_text: "A cute cat"
     }
   )
 end

 def create_complex_post(session) do
   # More complex rich text example with the sigil
   text = ~f"""
   Hey @everyone.bsky.social! 

   Here's my *big announcement*:
   I'm working on a new #bluesky project with @alice.sky and @bob.bsky!

   Check out our progress:
   - [GitHub repo](https://github.com/project)  
   - [Project docs](https://docs.project.com)

   _Let me know what you think!_ 💭
   """

   ProtoRune.create_post(session, text: text)
 end
end
