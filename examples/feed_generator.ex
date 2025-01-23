# examples/feed_generator.ex
defmodule ExampleFeedGenerator do
  use ProtoRune.Feed.Generator,
    name: "Proto Feed",
    description: "Example feed showing Elixir posts"

  @impl true
  def handle_post(post, _context) do
    # Check if post mentions Elixir
    if String.contains?(post.text, ["elixir", "Elixir"]) do
      # Return post in feed with score
      {:cont, score: 1.0}
    else
      :skip
    end
  end

  @impl true
  def get_feed(_params) do
    posts = ProtoRune.Feed.get_posts()
    
    posts
    |> Enum.filter(&post_contains_elixir?/1)
    |> Enum.sort_by(& &1.indexed_at, :desc)
    |> Enum.take(50)
  end

  defp post_contains_elixir?(post) do
    String.contains?(post.text, ["elixir", "Elixir"]) 
  end
end
