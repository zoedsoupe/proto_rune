# RFC: ProtoRune Lexicon Implementation Structure

## Abstract

This RFC proposes an implementation strategy for AT Protocol lexicons in ProtoRune. The approach uses Ecto for record validation through embedded schemas while leveraging schemaless changesets for query/procedure parameters. This provides type safety, validation, and clear documentation with a focus on developer experience and efficient implementation patterns.

## Background

AT Protocol lexicons define schemas and behaviors for protocol operations. These lexicons frequently reference each other, creating complex dependency relationships. ProtoRune needs stable Elixir modules that provide:

- Type safety through typespecs
- Runtime validation using Ecto
- Clear documentation and examples
- Consistent module organization
- Proper handling of circular dependencies

## Module Organization

Lexicons will be organized following AT Protocol's namespace structure:

```
lib/
└── lexicon/
    ├── app/
    │   └── bsky/
    │       ├── feed/
    │       │   ├── post.ex          # Record
    │       │   ├── like.ex          # Record
    │       │   └── get_timeline.ex  # Query
    │       └── actor/
    │           └── profile.ex       # Record
    └── com/
        └── atproto/
            └── repo/
                ├── create_record.ex # Procedure
                └── list_records.ex  # Query
```

Each file corresponds to a single lexicon, with a consistent naming pattern based on the NSID. The modules live under the `Lexicon` namespace.

## Implementation Approach

### 1. Record Types: Embedded Schemas with Builder Pattern

Records use Ecto's embedded schemas for validation and structure:

```elixir
defmodule Lexicon.App.Bsky.Feed.Post do
  @moduledoc """
  Record containing a Bluesky post.
  
  NSID: app.bsky.feed.post
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @type t :: %__MODULE__{
    text: String.t(),
    created_at: DateTime.t(),
    langs: [String.t()] | nil,
    embed: embed() | nil,
    reply_to: reference() | nil,
    facets: [facet()]
  }
  
  @primary_key false
  embedded_schema do
    field :text, :string
    field :created_at, :utc_datetime
    field :langs, {:array, :string}
    
    embeds_one :reply_to, Reference
    embeds_one :embed, Embed
    embeds_many :facets, Facet
  end
  
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:text, :created_at, :langs])
    |> validate_required([:text, :created_at])
    |> validate_length(:text, max: 300)
    |> cast_embed(:reply_to)
    |> cast_embed(:embed)
    |> cast_embed(:facets)
  end
  
  @doc """
  Creates a new post struct with the given attributes.
  """
  def new(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> case do
      %{valid?: true} = changeset -> {:ok, Ecto.Changeset.apply_changes(changeset)}
      changeset -> {:error, changeset}
    end
  end
  
  @doc """
  Adds an image to the post.
  
  ## Examples
  
      post = Post.new(text: "Check out this photo!")
      |> Post.with_image(%{alt: "A mountain", image: blob})
  """
  def with_image(post, image_params) when is_map(image_params) do
    current_images = case post.embed do
      %{images: images} when is_list(images) -> images
      _ -> []
    end
    
    embed = %{
      type: "app.bsky.embed.images",
      images: current_images ++ [image_params]
    }
    
    %{post | embed: embed}
  end
  
  @doc """
  Configures the post as a reply to another post.
  
  ## Examples
  
      post = Post.new(text: "Great point!")
      |> Post.as_reply(original_post.uri, parent_post.uri)
  """
  def as_reply(post, root_uri, parent_uri \\ nil) do
    reply_to = %{
      root: %{uri: root_uri},
      parent: %{uri: parent_uri || root_uri}
    }
    
    %{post | reply_to: reply_to}
  end
  
  # Nested schemas...
  
  defmodule Reference do
    use Ecto.Schema
    import Ecto.Changeset
    
    @primary_key false
    embedded_schema do
      field :root, :map
      field :parent, :map
    end
    
    def changeset(reference, attrs) do
      reference
      |> cast(attrs, [:root, :parent])
      |> validate_required([:root])
    end
  end
  
  defmodule Embed do
    use Ecto.Schema
    import Ecto.Changeset
    
    @primary_key false
    embedded_schema do
      field :type, :string
      field :images, {:array, :map}
      field :external, :map
      field :record, :map
    end
    
    def changeset(embed, attrs) do
      embed
      |> cast(attrs, [:type, :images, :external, :record])
      |> validate_required([:type])
    end
  end
  
  defmodule Facet do
    # Facet schema implementation
  end
end
```

### 2. Query Types: Schemaless Changesets

Queries are implemented using schemaless changesets for lightweight validation:

```elixir
defmodule Lexicon.App.Bsky.Feed.GetTimeline do
  @moduledoc """
  Query to retrieve a user's timeline.
  
  NSID: app.bsky.feed.getTimeline
  """
  
  import Ecto.Changeset
  
  @param_types %{
    limit: :integer,
    cursor: :string,
    algorithm: :string
  }
  
  @output_types %{
    cursor: :string,
    feed: {:array, :map}
  }
  
  @type params :: %{
    optional(:limit) => integer(),
    optional(:cursor) => String.t(),
    optional(:algorithm) => String.t()
  }
  
  @type output :: %{
    optional(:cursor) => String.t(),
    required(:feed) => [feed_item()]
  }
  
  @type feed_item :: %{
    required(:post) => map(),
    optional(:reason) => map()
  }
  
  @doc """
  Validates the query parameters.
  """
  def validate_params(params) do
    {%{}, @param_types}
    |> cast(params, Map.keys(@param_types))
    |> validate_number(:limit, greater_than: 0, less_than_or_equal_to: 100)
  end
  
  @doc """
  Execute this query with the given parameters.
  """
  def execute(session, params \\ %{}) do
    params
    |> validate_params()
    |> case do
      %{valid?: true} = changeset ->
        validated_params = apply_changes(changeset)
        ProtoRune.XRPC.query(session, "app.bsky.feed.getTimeline", validated_params)
      
      changeset ->
        {:error, changeset}
    end
  end
  
  @doc """
  Validates the response data structure.
  """
  def validate_output(data) do
    {%{}, @output_types}
    |> cast(data, Map.keys(@output_types))
    |> validate_required([:feed])
  end
end
```

### 3. Procedure Types: Schemaless Changesets

Procedures follow a similar pattern to queries, using schemaless changesets:

```elixir
defmodule Lexicon.Com.Atproto.Repo.CreateRecord do
  @moduledoc """
  Procedure to create a new record in a repository.
  
  NSID: com.atproto.repo.createRecord
  """
  
  import Ecto.Changeset
  
  @input_types %{
    repo: :string,
    collection: :string,
    rkey: :string,
    validate: :boolean,
    record: :map
  }
  
  @output_types %{
    uri: :string,
    cid: :string
  }
  
  @type input :: %{
    required(:repo) => String.t(),
    required(:collection) => String.t(),
    optional(:rkey) => String.t(),
    optional(:validate) => boolean(),
    required(:record) => map()
  }
  
  @type output :: %{
    required(:uri) => String.t(),
    required(:cid) => String.t()
  }
  
  @doc """
  Validates the procedure input.
  """
  def validate_input(input) do
    {%{}, @input_types}
    |> cast(input, Map.keys(@input_types))
    |> validate_required([:repo, :collection, :record])
  end
  
  @doc """
  Execute this procedure with the given input.
  """
  def execute(session, input) do
    input
    |> validate_input()
    |> case do
      %{valid?: true} = changeset ->
        validated_input = apply_changes(changeset)
        ProtoRune.XRPC.procedure(session, "com.atproto.repo.createRecord", validated_input)
      
      changeset ->
        {:error, changeset}
    end
  end
  
  @doc """
  Validates the procedure output.
  """
  def validate_output(data) do
    {%{}, @output_types}
    |> cast(data, Map.keys(@output_types))
    |> validate_required([:uri, :cid])
  end
end
```

## Handling Circular Dependencies

To manage circular dependencies between lexicons:

1. **Module References in Typespecs**: Use module references without creating circular module dependencies
2. **Schemaless Data Validation**: Use generic map validation for circular references
3. **Validation Functions**: Implement separate validation functions for circular references

Example:

```elixir
defmodule Lexicon.App.Bsky.Feed.Post do
  # Type definition references another module
  @type t :: %__MODULE__{
    # Fields...
    embed: embed()
  }
  
  # Validation handles references without creating circular dependencies
  def validate_embed(embed_data) when is_map(embed_data) do
    case embed_data do
      %{type: "app.bsky.embed.record"} ->
        # Validate record embed
        
      %{type: "app.bsky.embed.images"} ->
        # Validate images embed
        
      _ ->
        {:error, :invalid_embed_type}
    end
  end
end
```

## Rich Text Handling

Implement rich text handling with a dedicated module:

```elixir
defmodule Lexicon.App.Bsky.RichText do
  @moduledoc """
  Utilities for working with rich text content in AT Protocol.
  
  Handles facets like mentions, links, and hashtags.
  """
  
  @doc """
  Creates rich text with facets.
  
  ## Examples
  
      RichText.new("Hello @alice!")
      |> RichText.add_mention("alice.bsky.social", 6, 12)
  """
  def new(text) when is_binary(text) do
    %{text: text, facets: []}
  end
  
  @doc """
  Adds a mention facet to rich text.
  """
  def add_mention(rich_text, handle, start_index, end_index) do
    facet = %{
      index: %{
        byteStart: start_index,
        byteEnd: end_index
      },
      features: [
        %{
          $type: "app.bsky.richtext.facet#mention",
          did: handle
        }
      ]
    }
    
    %{rich_text | facets: [facet | rich_text.facets]}
  end
  
  @doc """
  Adds a link facet to rich text.
  """
  def add_link(rich_text, uri, start_index, end_index) do
    facet = %{
      index: %{
        byteStart: start_index,
        byteEnd: end_index
      },
      features: [
        %{
          $type: "app.bsky.richtext.facet#link",
          uri: uri
        }
      ]
    }
    
    %{rich_text | facets: [facet | rich_text.facets]}
  end
  
  @doc """
  Adds a hashtag facet to rich text.
  """
  def add_hashtag(rich_text, tag, start_index, end_index) do
    facet = %{
      index: %{
        byteStart: start_index,
        byteEnd: end_index
      },
      features: [
        %{
          $type: "app.bsky.richtext.facet#tag",
          tag: tag
        }
      ]
    }
    
    %{rich_text | facets: [facet | rich_text.facets]}
  end
  
  @doc """
  Parses text to automatically detect and add facets.
  """
  def parse(text) when is_binary(text) do
    rich_text = new(text)
    
    # Parse for mentions (starting with @)
    # Parse for hashtags (starting with #)
    # Parse for links (starting with http:// or https://)
    
    # Return rich_text with facets
    rich_text
  end
end
```

## Example Implementation: Profile Record

```elixir
defmodule Lexicon.App.Bsky.Actor.Profile do
  @moduledoc """
  Record representing a user profile.
  
  NSID: app.bsky.actor.profile
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @type t :: %__MODULE__{
    display_name: String.t() | nil,
    description: String.t() | nil,
    avatar: map() | nil,
    banner: map() | nil
  }
  
  @primary_key false
  embedded_schema do
    field :display_name, :string
    field :description, :string
    field :avatar, :map
    field :banner, :map
  end
  
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:display_name, :description, :avatar, :banner])
    |> validate_length(:display_name, max: 64)
    |> validate_length(:description, max: 256)
  end
  
  def new(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> case do
      %{valid?: true} = changeset -> {:ok, Ecto.Changeset.apply_changes(changeset)}
      changeset -> {:error, changeset}
    end
  end
  
  @doc """
  Sets the avatar image for the profile.
  """
  def with_avatar(profile, blob_data, alt_text) do
    avatar = %{
      image: blob_data,
      alt: alt_text
    }
    
    %{profile | avatar: avatar}
  end
  
  @doc """
  Sets the banner image for the profile.
  """
  def with_banner(profile, blob_data, alt_text) do
    banner = %{
      image: blob_data,
      alt: alt_text
    }
    
    %{profile | banner: banner}
  end
end
```

## Example Implementation: Profile Query

```elixir
defmodule Lexicon.App.Bsky.Actor.GetProfile do
  @moduledoc """
  Query to retrieve a user profile.
  
  NSID: app.bsky.actor.getProfile
  """
  
  import Ecto.Changeset
  
  @param_types %{
    actor: :string
  }
  
  @output_types %{
    did: :string,
    handle: :string,
    display_name: :string,
    description: :string,
    avatar: :string,
    banner: :string,
    followers_count: :integer,
    follows_count: :integer,
    posts_count: :integer,
    indexed_at: :utc_datetime
  }
  
  @type params :: %{
    required(:actor) => String.t()
  }
  
  @type output :: %{
    required(:did) => String.t(),
    required(:handle) => String.t(),
    optional(:display_name) => String.t(),
    optional(:description) => String.t(),
    optional(:avatar) => String.t(),
    optional(:banner) => String.t(),
    required(:followers_count) => integer(),
    required(:follows_count) => integer(),
    required(:posts_count) => integer(),
    required(:indexed_at) => DateTime.t()
  }
  
  @doc """
  Validates the query parameters.
  """
  def validate_params(params) do
    {%{}, @param_types}
    |> cast(params, Map.keys(@param_types))
    |> validate_required([:actor])
  end
  
  @doc """
  Execute this query with the given parameters.
  """
  def execute(session, params) do
    params
    |> validate_params()
    |> case do
      %{valid?: true} = changeset ->
        validated_params = apply_changes(changeset)
        ProtoRune.XRPC.query(session, "app.bsky.actor.getProfile", validated_params)
      
      changeset ->
        {:error, changeset}
    end
  end
  
  @doc """
  Validates the response data structure.
  """
  def validate_output(data) do
    {%{}, @output_types}
    |> cast(data, Map.keys(@output_types))
    |> validate_required([:did, :handle, :followers_count, :follows_count, :posts_count, :indexed_at])
  end
end
```

## High-Level API Integration

Create high-level API modules that use the lexicon modules:

```elixir
defmodule Bluesky.Post do
  @moduledoc """
  Simplified API for working with Bluesky posts.
  """
  
  alias Lexicon.App.Bsky.Feed.Post
  alias ProtoRune.RichText
  
  @doc """
  Creates a new post.
  """
  def create(session, text) when is_binary(text) do
    attrs = %{
      text: text,
      created_at: DateTime.utc_now()
    }
    
    with {:ok, post} <- Post.new(attrs) do
      Lexicon.Com.Atproto.Repo.CreateRecord.execute(session, %{
        repo: session.did,
        collection: "app.bsky.feed.post",
        record: post
      })
    end
  end
  
  @doc """
  Creates a post with rich text.
  """
  def create_rich(session, rich_text) do
    attrs = %{
      text: rich_text.text,
      facets: rich_text.facets,
      created_at: DateTime.utc_now()
    }
    
    with {:ok, post} <- Post.new(attrs) do
      Lexicon.Com.Atproto.Repo.CreateRecord.execute(session, %{
        repo: session.did,
        collection: "app.bsky.feed.post",
        record: post
      })
    end
  end
  
  @doc """
  Creates a post with images.
  """
  def create_with_images(session, text, images) when is_list(images) do
    {:ok, post} = Post.new(%{
      text: text,
      created_at: DateTime.utc_now()
    })
    
    post = Enum.reduce(images, post, fn image, acc ->
      Post.with_image(acc, image)
    end)
    
    Lexicon.Com.Atproto.Repo.CreateRecord.execute(session, %{
      repo: session.did,
      collection: "app.bsky.feed.post",
      record: post
    })
  end
end
```

## Testing Strategy

For testing lexicon implementations:

1. **Schema Validation Tests**: Verify constraints work correctly
2. **Builder Pattern Tests**: Test record transformation utilities
3. **API Integration Tests**: Use VCR to record and replay HTTP interactions
4. **Property Tests**: Test with generated inputs across valid ranges
5. **End-to-End Tests**: Test full workflows like posting and retrieving content

## Implementation Plan

1. **Core Types Phase**
   - Implement base structures for records, queries, and procedures
   - Set up validation patterns for all three types
   - Create builder patterns for common records

2. **Core Protocol Phase**
   - Implement com.atproto.repo.* lexicons
   - Implement com.atproto.server.* lexicons
   - Implement com.atproto.sync.* lexicons

3. **Bluesky App Phase**  
   - Implement app.bsky.actor.* lexicons
   - Implement app.bsky.feed.* lexicons
   - Implement app.bsky.graph.* lexicons

4. **Advanced Features Phase**
   - Implement rich text utilities
   - Implement embed handling
   - Add convenience APIs and documentation

## The Power of Combined Patterns

The RFC outlines an excellent approach for implementing AT Protocol lexicons in ProtoRune. I'd like to expand on how the Ecto changeset pattern and builder pattern can work together even more effectively.

This combined approach creates a powerful development experience with:

1. Strong validation guarantees from Ecto changesets
2. Expressive, fluent APIs from the builder pattern
3. Clear separation between data validation and domain operations
4. Type safety maintained throughout the construction process

### Pattern Interactions

The core insight is that these patterns serve complementary purposes:

```
┌───────────────────────┐          ┌───────────────────────┐
│ Ecto Changeset Pattern │          │ Builder Pattern       │
├───────────────────────┤          ├───────────────────────┤
│ • Initial validation   │          │ • Complex composition │
│ • Type casting         │ ───────► │ • Semantic operations │
│ • Field constraints    │          │ • Operation validation│
│ • Error collection     │          │ • Maintains invariants│
└───────────────────────┘          └───────────────────────┘
```

## Implementing the Patterns in ProtoRune

The implementation in your RFC already demonstrates this approach. Let's enhance it with additional techniques and considerations:

### 1. Focused Validation in Builder Functions

Each builder function should validate only what it needs to, using schemaless changesets for efficient validation:

```elixir
def with_image(%__MODULE__{} = post, image_params) do
  # Define the schema for just the image data
  types = %{
    binary: :binary,
    alt: :string,
    mime_type: :string
  }
  
  with {:ok, validated_image} <- validate_image_params(image_params) do
    # Construct the embed
    embed = %Embed{
      type: "app.bsky.embed.images",
      images: [validated_image]
    }
    
    # Return updated post
    %{post | embed: embed}
  end
end

defp validate_image_params(params) do
  types = %{binary: :binary, alt: :string, mime_type: :string}
  
  {%{}, types}
  |> cast(params, Map.keys(types))
  |> validate_required([:binary, :alt])
  |> validate_length(:alt, max: 300)
  |> apply_action(:validate)
end
```

### 2. Maintaining Type Safety in Builders

Builder functions should guarantee the returned object always meets the schema requirements:

```elixir
@spec with_image(%__MODULE__{}, map()) :: %__MODULE__{} | {:error, Ecto.Changeset.t()}
def with_image(%__MODULE__{} = post, image_params) when is_map(image_params) do
  # Implementation...
end
```

### 3. Intelligent Error Handling Strategy

Consider different error handling strategies in builder functions:

```elixir
# Option 1: Return errors (more functional)
def with_reference(%__MODULE__{} = post, reference_params) do
  case validate_reference(reference_params) do
    {:ok, validated_ref} -> %{post | reply_to: validated_ref}
    error -> error
  end
end

# Option 2: Raise exceptions (more pipeline-friendly)
def with_external_link!(%__MODULE__{} = post, link_params) do
  case validate_link(link_params) do
    {:ok, validated_link} -> %{post | embed: create_link_embed(validated_link)}
    {:error, changeset} -> raise "Invalid link: #{inspect(changeset.errors)}"
  end
end
```

### 4. Contextual Validations

Some validations depend on the context of the whole object:

```elixir
def finalize(%__MODULE__{} = post) do
  # Perform validations that depend on the entire post structure
  cond do
    is_nil(post.text) and is_nil(post.embed) ->
      {:error, "Post must have either text or embed"}
      
    String.length(post.text) > 300 ->
      {:error, "Text exceeds maximum length"}
      
    true ->
      {:ok, post}
  end
end
```

## Example: Enhanced Post Implementation

Let's see a more complete example that demonstrates these techniques:

```elixir
defmodule Lexicon.App.Bsky.Feed.Post do
  use Ecto.Schema
  import Ecto.Changeset
  
  @type t :: %__MODULE__{
    text: String.t(),
    created_at: DateTime.t(),
    langs: [String.t()] | nil,
    embed: embed() | nil,
    reply_to: reference() | nil,
    facets: [facet()]
  }
  
  @primary_key false
  embedded_schema do
    field :text, :string
    field :created_at, :utc_datetime
    field :langs, {:array, :string}
    
    embeds_one :reply_to, Reference
    embeds_one :embed, Embed
    embeds_many :facets, Facet
  end
  
  # Initial validation with changeset
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:text, :created_at, :langs])
    |> validate_required([:created_at])
    |> validate_length(:text, max: 300)
    |> cast_embed(:reply_to)
    |> cast_embed(:embed)
    |> cast_embed(:facets)
    |> validate_post_content()
  end
  
  defp validate_post_content(changeset) do
    text = get_field(changeset, :text)
    embed = get_field(changeset, :embed)
    
    if is_nil(text) and is_nil(embed) do
      add_error(changeset, :text, "Post must have either text or embed")
    else
      changeset
    end
  end
  
  @doc """
  Creates a new post with the given attributes.
  
  ## Examples
  
      {:ok, post} = Post.new(text: "Hello world!", created_at: DateTime.utc_now())
  """
  @spec new(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def new(attrs) do
    %__MODULE__{}
    |> changeset(Map.put_new_lazy(attrs, :created_at, &DateTime.utc_now/0))
    |> apply_action(:insert)
  end
  
  @doc """
  Creates a new post, raising an exception if validation fails.
  """
  @spec new!(map()) :: t() | no_return()
  def new!(attrs) do
    case new(attrs) do
      {:ok, post} -> post
      {:error, changeset} -> raise "Invalid post: #{inspect(changeset.errors)}"
    end
  end
  
  @doc """
  Adds an image to the post.
  
  ## Examples
  
      post
      |> Post.with_image(binary: image_data, alt: "A scenic mountain view")
  """
  @spec with_image(t(), map()) :: t() | {:error, Ecto.Changeset.t()}
  def with_image(%__MODULE__{} = post, image_params) do
    case validate_image(image_params) do
      {:ok, image} ->
        # Get current images or initialize empty list
        current_images = case post.embed do
          %{type: "app.bsky.embed.images", images: imgs} when is_list(imgs) -> imgs
          _ -> []
        end
        
        # Create or update the embed
        embed = %{
          type: "app.bsky.embed.images",
          images: current_images ++ [image]
        }
        
        %{post | embed: embed}
        
      error -> error
    end
  end
  
  @doc """
  Adds a link to the post.
  
  ## Examples
  
      post
      |> Post.with_external_link(
        uri: "https://example.com",
        title: "Example Website",
        description: "An example website"
      )
  """
  @spec with_external_link(t(), map()) :: t() | {:error, Ecto.Changeset.t()}
  def with_external_link(%__MODULE__{} = post, link_params) do
    case validate_link(link_params) do
      {:ok, link} ->
        embed = %{
          type: "app.bsky.embed.external",
          external: link
        }
        
        %{post | embed: embed}
        
      error -> error
    end
  end
  
  @doc """
  Configures the post as a reply to another post.
  
  ## Examples
  
      post
      |> Post.as_reply(root: original_post.uri, parent: parent_post.uri)
  """
  @spec as_reply(t(), map()) :: t() | {:error, Ecto.Changeset.t()}
  def as_reply(%__MODULE__{} = post, ref_params) do
    case validate_reference(ref_params) do
      {:ok, ref} -> %{post | reply_to: ref}
      error -> error
    end
  end
  
  # Validation functions for builder operations
  
  defp validate_image(params) do
    types = %{binary: :binary, alt: :string, mime_type: :string}
    
    {%{}, types}
    |> cast(params, Map.keys(types))
    |> validate_required([:binary, :alt])
    |> validate_length(:alt, max: 300)
    |> apply_action(:validate)
  end
  
  defp validate_link(params) do
    types = %{uri: :string, title: :string, description: :string, thumb: :binary}
    
    {%{}, types}
    |> cast(params, Map.keys(types))
    |> validate_required([:uri])
    |> validate_length(:title, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_format(:uri, ~r/^https?:\/\//)
    |> apply_action(:validate)
  end
  
  defp validate_reference(params) do
    types = %{root: :map, parent: :map}
    
    {%{}, types}
    |> cast(params, Map.keys(types))
    |> validate_required([:root])
    |> apply_action(:validate)
  end
  
  # Nested schemas similar to your examples...
end
```

## Rich Text Integration

The RichText module can be enhanced to better integrate with the Post builder pattern:

```elixir
defmodule Lexicon.App.Bsky.Feed.Post do
  # Extend the Post module with a rich_text function
  
  @doc """
  Adds rich text facets to the post.
  
  ## Examples
  
      {:ok, post} = Post.new(text: "Hello @alice!")
      post = Post.with_rich_text(post, fn rt ->
        rt
        |> RichText.add_mention("alice.bsky.social", 6, 12)
      end)
  """
  @spec with_rich_text(t(), (map() -> map())) :: t()
  def with_rich_text(%__MODULE__{} = post, builder_fn) when is_function(builder_fn, 1) do
    # Start with current text and facets
    rich_text = %{
      text: post.text,
      facets: post.facets || []
    }
    
    # Apply builder function
    updated = builder_fn.(rich_text)
    
    # Update post with new facets
    %{post | text: updated.text, facets: updated.facets}
  end
end
```

## Testing Combined Patterns

For testing this combined approach, consider:

1. **Unit tests for individual builders**: Each builder function should be tested in isolation

```elixir
test "with_image adds an image to an empty post" do
  {:ok, post} = Post.new(text: "Check out this photo!")
  image_params = %{binary: <<1, 2, 3>>, alt: "Test image"}
  
  result = Post.with_image(post, image_params)
  
  assert %Post{} = result
  assert result.embed.type == "app.bsky.embed.images"
  assert length(result.embed.images) == 1
  assert hd(result.embed.images).alt == "Test image"
end
```

2. **Integration tests for builder chains**: Test multiple builder functions in sequence

```elixir
test "builder chain creates a complete post" do
  {:ok, post} = Post.new(text: "Check out this link with an image!")
  
  result = post
    |> Post.with_external_link(%{uri: "https://example.com", title: "Example"})
    |> Post.with_rich_text(fn rt ->
      rt |> RichText.add_link("https://example.com", 16, 20)
    end)
    
  assert %Post{} = result
  assert result.embed.type == "app.bsky.embed.external"
  assert length(result.facets) == 1
end
```

## Performance Considerations

When implementing the combined pattern approach, consider:

1. **Efficient validation**: Only validate what's necessary in each builder step
2. **Immutable data structures**: Leverage Elixir's immutability for efficient updates
3. **Lazy evaluation**: Use lazy initialization where appropriate
4. **Batch operations**: Allow batch processing where it makes sense

```elixir
def with_images(%__MODULE__{} = post, images) when is_list(images) do
  # Validate all images at once
  with {:ok, validated_images} <- validate_images(images) do
    # Update the post with all images in a single operation
    embed = %{
      type: "app.bsky.embed.images",
      images: validated_images
    }
    
    %{post | embed: embed}
  end
end

defp validate_images(images) do
  # Map validation over all images
  Enum.reduce_while(images, {:ok, []}, fn image, {:ok, acc} ->
    case validate_image(image) do
      {:ok, validated} -> {:cont, {:ok, [validated | acc]}}
      error -> {:halt, error}
    end
  end)
  |> case do
    {:ok, validated} -> {:ok, Enum.reverse(validated)}
    error -> error
  end
end
```

## Advanced Record Operations

For more complex record types, consider implementing cross-field validations:

```elixir
defmodule Lexicon.App.Bsky.Labeler.Service do
  # Schema definition similar to your examples...
  
  def changeset(labeler, attrs) do
    labeler
    |> cast(attrs, [:policies, :labels_supported])
    |> validate_required([:policies])
    |> validate_labels_consistency()
  end
  
  defp validate_labels_consistency(changeset) do
    labels_supported = get_field(changeset, :labels_supported) || []
    policies = get_field(changeset, :policies)
    
    if policies && Enum.any?(policies.labels, fn label -> label not in labels_supported end) do
      add_error(changeset, :policies, "contains labels not in labels_supported")
    else
      changeset
    end
  end
end
```

## Conclusion

The approach outlined in your RFC provides an excellent foundation for implementing AT Protocol lexicons in ProtoRune. By enhancing it with these combined pattern techniques, you can create a powerful, expressive, and type-safe implementation that maintains strict validation guarantees while offering a delightful developer experience.

This combined approach:
- Uses Ecto changesets for base validation
- Employs builder functions for complex operations
- Maintains type safety throughout
- Provides clear separation of concerns
- Offers a fluent, chainable API

With these enhancements, ProtoRune will provide a robust foundation for building AT Protocol applications with confidence.

# Record Implementation Patterns in ProtoRune

## Pattern Selection Guide

When implementing AT Protocol lexicons in ProtoRune, it's important to choose the appropriate pattern based on the complexity and construction needs of each record type.

### Complex Records: Combined Pattern (Ecto Changeset + Builder Pattern)

These records benefit from the combined approach due to their complex structure, multiple optional components, or need for incremental construction:

| Record Type | Rationale |
|-------------|-----------|
| `app.bsky.feed.post` | Complex structure with rich text, embeds (images/links), replies, and facets that are best added incrementally |
| `app.bsky.actor.profile` | Contains optional components like avatars and banners that benefit from dedicated builder functions |
| `app.bsky.embed.images` | Multiple images with metadata that can be added incrementally |
| `app.bsky.embed.external` | External links with optional thumbnail, title, and description fields |
| `app.bsky.embed.recordWithMedia` | Combines record references with media elements |
| `app.bsky.feed.generator` | Complex configuration with multiple optional parameters |
| `app.bsky.graph.list` | Lists with purpose, description, and avatar that benefit from builder functions |
| `app.bsky.labeler.service` | Complex service definition with policies, labels, and configuration |
| `app.bsky.feed.threadgate` | Has complex rules for controlling who can reply |

**Implementation example:**

```elixir
defmodule Lexicon.App.Bsky.Feed.Post do
  use Ecto.Schema
  import Ecto.Changeset
  
  # Schema definition...
  
  # Base changeset + constructor
  def new(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end
  
  # Builder functions
  def with_image(post, image_params) do
    # Implementation...
  end
  
  def as_reply(post, reply_params) do
    # Implementation...
  end
  
  def with_rich_text(post, builder_fn) do
    # Implementation...
  end
end
```

### Simple Records: Changeset-Only Pattern

These records have a straightforward structure with few fields, minimal validation requirements, and typically don't require incremental construction:

| Record Type | Rationale |
|-------------|-----------|
| `app.bsky.feed.like` | Simple record that only references another post with minimal metadata |
| `app.bsky.feed.repost` | Similar to like, just references another post with creation timestamp |
| `app.bsky.graph.follow` | Only contains a subject DID with minimal additional data |
| `app.bsky.graph.block` | Simple record referencing a blocked user |
| `app.bsky.actor.preferenceItem` | Individual preference settings are typically simple key-value pairs |
| `app.bsky.richtext.facet` | Individual facets are relatively simple structures |
| `app.bsky.notification.listNotifications` | Simple object structure with fixed fields |
| `app.bsky.actor.getSuggestions` | Simple query parameters without complex structures |
| `com.atproto.label.defs` | Label definitions have few fields and simple validation |

**Implementation example:**

```elixir
defmodule Lexicon.App.Bsky.Feed.Like do
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key false
  embedded_schema do
    field :subject, :map
    field :created_at, :utc_datetime
  end
  
  def changeset(like, attrs) do
    like
    |> cast(attrs, [:subject, :created_at])
    |> validate_required([:subject, :created_at])
    |> validate_subject()
  end
  
  def new(attrs) do
    attrs = Map.put_new_lazy(attrs, :created_at, &DateTime.utc_now/0)
    
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end
  
  defp validate_subject(changeset) do
    # Validate subject structure
    # ...
    changeset
  end
end
```

### Borderline Cases: Consider Context

These records could use either pattern depending on implementation details and feature requirements:

| Record Type | Considerations |
|-------------|----------------|
| `app.bsky.graph.listitem` | If list items have complex metadata or attachments, use combined pattern; otherwise changeset-only |
| `app.bsky.actor.preferences` | If implementing a system with many preference types and complex validation, use combined; otherwise changeset-only |
| `app.bsky.feed.threadgate` | If thread rules are simple, changeset-only may suffice; for complex rule building, use combined |
| `app.bsky.embed.record` | If record embeds need additional context or processing, use combined; otherwise changeset-only |

## Implementation Strategy

When deciding which pattern to use:

1. **Start simple**: Begin with the changeset-only pattern for all records
2. **Identify complexity**: Determine which records have complex construction needs
3. **Add builders incrementally**: Convert complex records to the combined pattern as needed
4. **Maintain consistency**: Use similar builder function names and patterns across all record types

This approach allows for a consistent, gradual implementation of lexicons while ensuring that complex records have appropriate builder functions when needed.

## Evolving Patterns

As the AT Protocol evolves and new lexicon features are added, reevaluate your pattern choices. A record that started simple might gain complexity over time, warranting a transition to the combined pattern.

The combined pattern offers more flexibility and can always support simple use cases, while the changeset-only pattern is more concise for straightforward records. Choose the right tool for each specific lexicon implementation.

# Implementing Definition Lexicons in ProtoRune

## Understanding Definition Lexicons

Definition lexicons (those ending with `defs` like `app.bsky.feed.defs`) serve a special purpose in the AT Protocol ecosystem. They define reusable data structures, constants, and type definitions that are referenced by other lexicons. Unlike records, queries, or procedures, definitions are not directly instantiated or called - they're building blocks for other lexicons.

Examples include:
- `app.bsky.feed.defs` (defining feed-related structures)
- `app.bsky.actor.defs` (defining actor-related structures)
- `com.atproto.label.defs` (defining label structures)

## Proposed Implementation Strategy

For definition lexicons, I recommend implementing them as specialized modules that export:
1. Type specifications
2. Embedded schemas
3. Validation functions

### Module Structure

```elixir
defmodule Lexicon.App.Bsky.Feed.Defs do
  @moduledoc """
  Definitions for feed-related data structures.
  
  NSID: app.bsky.feed.defs
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  # Define each type as a nested module
  defmodule PostView do
    @moduledoc """
    A view of a post.
    """
    
    use Ecto.Schema
    import Ecto.Changeset
    
    @type t :: %__MODULE__{
      uri: String.t(),
      cid: String.t(),
      author: map(),
      record: map(),
      embed: map() | nil,
      # Other fields...
    }
    
    @primary_key false
    embedded_schema do
      field :uri, :string
      field :cid, :string
      field :author, :map
      field :record, :map
      field :embed, :map
      # Other fields...
    end
    
    def changeset(post_view, attrs) do
      post_view
      |> cast(attrs, [:uri, :cid, :author, :record, :embed])
      |> validate_required([:uri, :cid, :author, :record])
    end
    
    @doc """
    Validates a post view structure.
    """
    def validate(data) when is_map(data) do
      %__MODULE__{}
      |> changeset(data)
      |> apply_action(:validate)
    end
  end
  
  defmodule ViewerState do
    @moduledoc """
    The state of the post from the viewer's perspective.
    """
    
    use Ecto.Schema
    import Ecto.Changeset
    
    @type t :: %__MODULE__{
      repost_uri: String.t() | nil,
      like_uri: String.t() | nil,
      # Other fields...
    }
    
    @primary_key false
    embedded_schema do
      field :repost_uri, :string
      field :like_uri, :string
      # Other fields...
    end
    
    def changeset(viewer_state, attrs) do
      viewer_state
      |> cast(attrs, [:repost_uri, :like_uri])
      # Any additional validation...
    end
    
    @doc """
    Validates a viewer state structure.
    """
    def validate(data) when is_map(data) do
      %__MODULE__{}
      |> changeset(data)
      |> apply_action(:validate)
    end
  end
  
  # More definition modules as needed...
  
  # For union types, create a module with validation functions for each variant
  defmodule FeedViewUnion do
    @moduledoc """
    Union type for different feed view types.
    """
    
    @doc """
    Validates a feed view union object.
    """
    def validate(%{type: "app.bsky.feed.defs#postView"} = data) do
      PostView.validate(data)
    end
    
    def validate(%{type: "app.bsky.feed.defs#notFoundPost"} = data) do
      # Validate not found post structure
      # ...
    end
    
    def validate(_) do
      {:error, :invalid_feed_view_type}
    end
  end
end
```

## Usage From Other Modules

Definition modules should be used by other lexicon implementations when they need those structures:

```elixir
defmodule Lexicon.App.Bsky.Feed.GetTimeline do
  alias Lexicon.App.Bsky.Feed.Defs.PostView
  
  # Output contains a feed which is an array of PostViews
  def validate_output(%{feed: feed} = data) when is_list(feed) do
    with {:ok, validated_feed} <- validate_feed_items(feed) do
      {:ok, %{data | feed: validated_feed}}
    end
  end
  
  defp validate_feed_items(feed_items) do
    Enum.reduce_while(feed_items, {:ok, []}, fn item, {:ok, acc} ->
      case PostView.validate(item) do
        {:ok, validated} -> {:cont, {:ok, [validated | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      error -> error
    end
  end
end
```

## Special Considerations for Definition Lexicons

### 1. Token Types

For lexicons that define token types (constants), implement them as module attributes:

```elixir
defmodule Lexicon.App.Bsky.Labeler.Defs do
  # Token definitions as module attributes
  @flag_spam "app.bsky.labeler.defs#flag-spam"
  @flag_violence "app.bsky.labeler.defs#flag-violence"
  
  # Export as functions for documentation and code completion
  def flag_spam, do: @flag_spam
  def flag_violence, do: @flag_violence
  
  # Provide helper to check if a value is a valid token
  def valid_flag?(flag) do
    flag in [@flag_spam, @flag_violence]
  end
end
```

### 2. Union Types

For union types, provide a validation function that handles all variants:

```elixir
defmodule Lexicon.Com.Atproto.Label.Defs do
  @doc """
  Validates a label value based on its $type field.
  """
  def validate_label(%{"$type" => "com.atproto.label.defs#selfLabels"} = label) do
    # Validate self labels
    # ...
  end
  
  def validate_label(%{"$type" => "com.atproto.label.defs#thirdPartyLabels"} = label) do
    # Validate third party labels
    # ...
  end
  
  def validate_label(_) do
    {:error, :invalid_label_type}
  end
end
```

### 3. Shared Code Generation

Definition lexicons should be included in the same code generation process as other lexicons to ensure consistency. The generator should detect definition lexicons and apply special rules for them.

## Cross-Importing Definition Types

One challenge with definitions is handling cross-references between lexicons. This can be solved by proper module naming and imports:

```elixir
defmodule Lexicon.App.Bsky.Feed.Post do
  # Import definitions from other lexicons
  alias Lexicon.App.Bsky.Actor.Defs.ProfileViewBasic
  alias Lexicon.App.Bsky.Feed.Defs.PostView
  
  # Use those definitions in typespecs
  @type timeline_item :: %{
    post: PostView.t(),
    author: ProfileViewBasic.t()
  }
  
  # And in validation functions
  def validate_timeline_item(item) do
    with {:ok, post} <- PostView.validate(item.post),
         {:ok, author} <- ProfileViewBasic.validate(item.author) do
      {:ok, %{post: post, author: author}}
    end
  end
end
```

## Conclusion

Definition lexicons should be implemented as modules containing nested type definitions with:
1. Clear type specifications
2. Embedded schemas for validation
3. Helper functions for creating and validating structures
4. Constants for token definitions
5. Proper documentation

This approach ensures that definition lexicons are properly integrated into the ProtoRune ecosystem, providing reusable building blocks for other lexicons while maintaining type safety and validation capabilities.

The design also supports the likely future expansion of AT Protocol lexicons by providing a flexible foundation that can evolve with the protocol.
