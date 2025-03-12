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

This approach leverages Ecto's strengths for validation while keeping implementation lightweight where appropriate. The schemaless changeset approach for queries and procedures reduces boilerplate while maintaining type safety and validation. The builder pattern for records provides an elegant, functional API for constructing complex data structures.