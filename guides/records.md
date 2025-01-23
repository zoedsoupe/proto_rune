# Working with Records in ProtoRune

Records are the fundamental data structures in AT Protocol. They represent everything from posts and profiles to likes and follows. Let's explore how ProtoRune helps you work with records in a type-safe and intuitive way.

## Understanding Records

In AT Protocol, a record is a piece of data that:
- Belongs to a specific collection (like "app.bsky.feed.post")
- Has a unique record key within that collection
- Follows a schema defined by a Lexicon
- Lives in a user's repository

ProtoRune represents records as Elixir structs with validation, basically a Ecto.Schema. For example:

> typespecs are abbreviated since it're automatically generated and also for brevity

```elixir
defmodule ProtoRune.Bsky.Post do
  use ProtoRune.Record, collection: "app.bsky.feed.post"

  @type t :: %__MODULE__{
    text: String.t(),
    created_at: DateTime.t(),
    langs: [String.t()] | nil,
    labels: [label()] | nil,
    embed: embed() | nil,
    reply_to: reference() | nil,
    facets: [facet()]
  }

  embedded_schema do
    field :text, :string
    field :langs, {:array, :string}
    field :created_at, :utc_datetime

    embeds_one :reply_to, Reference
    embeds_one :embed, Embed

    embeds_many :labels, Label
    embeds_many :facets, Facet
  end
end
```

## Record Operations

### Creating Records

Every record type provides a `new/1` function for creating instances:

```elixir
alias ProtoRune.Bsky.Post
alias ProtoRune.Bsky.Profile

# Create a post instance
post = Post.new(text: "Hello world!")
# Publish the post
{:ok, created} = Post.create(session, post)

# Create a profile instance with options
profile = Profile.new(
  display_name: "Zoey",
  description: "Elixir developer",
  avatar: %{
    image: File.read!("avatar.jpg"),
    alt: "Profile picture"
  }
)
# Create the profile record in the PDS
{:ok, created} = Profile.create(session, profile)
```

### Reading Records

Records can be fetched by their URI or by collection + record key:

```elixir
# Get by URI
{:ok, post} = Post.get(session, "at://did:plc:1234/app.bsky.feed.post/1234")

# Get by record key
{:ok, post} = Post.get(session, did: "did:plc:1234", rkey: "1234")

# List records from a collection
{:ok, posts} = Post.list(session, did: "did:plc:1234", limit: 50)
```

### Updating Records

Records are immutable in AT Protocol - an update creates a new version:

```elixir
# Update a profile
{:ok, _} = Profile.update(session, %{profile | description: "Updated bio"})
```

### Deleting Records

```elixir
# Delete by URI
{:ok, _} = Post.delete(session, "at://did:plc:1234/app.bsky.feed.post/1234")

# Delete by record key
{:ok, _} = Post.delete(session, rkey: "1234")
```

## Working with Complex Records

### Embedded Media

Posts can contain embedded media like images:

```elixir
# Create post with image
Post.new(text: "Check out this photo!")
|> Post.with_image(binary: File.read!("photo.jpg"), alt: "A scenic mountain view")
|> Post.with_image(binary: File.read!("cat.png"), alt: "An adorable black cat")
|> then(fn post -> Post.create(session, post) end)

# Create post instance with external link, cummulative
Post.new(text: "Interesting article")
|> Post.with_external_link(
  uri: "https://example.com/article",
  title: "Article Title",
  description: "Article description..."
)
|> then(fn post -> Post.create(session, post) end)
```

### Reply Threads

Posts can be replies to other posts:

```elixir
# Reply to a post
Post.new(text: "Great point!")
|> Post.with_reference(root: original_post, parent: parent_post)
|> then(fn post -> Post.create(session, post) end)

# Get a thread
{:ok, thread} = Post.get_thread(session, post_uri)
```

## Record Validation

ProtoRune validates records before sending them to the server:

```elixir
# Validation happens automatically on create/update
case Post.create(session, Post.new(text: 123)) do
  {:error, %Ecto.Changeset{valid?: false}} ->
    # Handle validation error
  {:ok, post} ->
    # Post created successfully
end

# Manual validation
case Post.validate(post) do
  {:ok, post} -> # Valid
  {:error, %Ecto.Changeset{valid?: false}} -> # Invalid
end
```

## Custom Record Types

You can define your own record types for custom lexicons:

```elixir
defmodule MyApp.CustomRecord do
  use ProtoRune.Record,
    collection: "com.example.custom",
    lexicon: "custom_lexicon.json"

  embedded_schema do
    field :field_1, :string
    field :field_2, :map
  end
  
  # Define your schema and functions...
end
```
