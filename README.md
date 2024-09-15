# ProtoRune

**ProtoRune** is an Elixir framework and client library for building applications on top of the ATProtocol, including **Bluesky** integration. Whether you're developing **bots**, **labelers**, **moderators**, or custom **app views**, ProtoRune provides a flexible and powerful way to interact with the protocol using Elixir.

## Features

- **XRPC Client**: Interact with ATProto services through a simple, extensible XRPC client.
- **Schema Generation**: Automatically generate schemas from ATProto `defs.json` files.
- **Bots & Labelers**: Create bots for content moderation, automated interactions, and more.
- **Moderation Tools**: Build labelers and moderation tools integrated with ATProto's labeling system.
- **Flexible Framework**: Use ProtoRune to build custom ATProto applications, including custom feeds, notifications, and more.

## Installation

Add ProtoRune to your `mix.exs`:

```elixir
def deps do
  [
    {:proto_rune, "~> 0.1.0"}
  ]
end
```

Run `mix deps.get` to install it.

## Getting Started

### 1. Setting Up a Simple Query

```elixir
defmodule MyApp.ProfileFetcher do
  alias ProtoRune.Session
  alias ProtoRune.Bsky.Actor.Defs.Profile

  @spec get_profile(Session.t, actor: String.t) :: {:ok, Profile.t} | {:error, term}
  def get_profile(%Session{} = session, actor: actor) do
    ProtoRune.Bsky.Actor.get_profile(session, actor: actor)
  end
end
```

### 2. Creating a Bot

```elixir
defmodule MyBot do
  use ProtoRune.Bot

  @impl true
  def handle_message(%{text: "Hello"}) do
    "Hi there!"
  end
end
```

### 3. Building Moderation Tools

```elixir
defmodule MyModerator do
  use ProtoRune.Moderator

  def label_inappropriate_content(content) do
    # Custom logic to label content
    ProtoRune.Label.apply_label(content, :inappropriate)
  end
end
```

Here's a section to add a roadmap to the README using checklists:

## Roadmap

- [x] **Basic XRPC Client**
    - Implement a client to interact with ATProto and Bluesky services via XRPC.
- [ ] **Schemas Parsing and Definition**
    - Define schemas like `ProfileBasicView` or even `Session` as structs
- [ ] **Schema Generation**
    - Automatically generate Elixir structs and typespecs from `defs.json` schema files.
- [x] **Authenticated Queries**
    - Support for authenticated queries using session tokens.
- [x] **Flexible Query and Procedure Macros**
    - Macros (`defquery` and `defprocedure`) to simplify the definition of queries and procedures.
- [ ] **Custom Bots**
    - Build an easy-to-use interface for creating bots that interact with ATProto services.
- [ ] **Labeling and Moderation Tools**
    - Provide built-in support for creating labelers and moderators for content on ATProto.
- [ ] **Advanced Error Handling**
    - Improve error handling for query execution and schema validation.
- [ ] **App Views and Custom Feeds**
    - Allow developers to create custom feeds and views based on the ATProto ecosystem.
- [ ] **Documentation and Examples**
    - Expand library documentation with detailed usage examples for bots, labelers, and moderators.

## Dynamic Schema Generation

ProtoRune includes tools for dynamically generating Elixir modules for ATProto schemas:

1. **Generate Schemas from defs.json**
    - Use the built-in Mix task to generate Elixir structs and typespecs for the schemas defined in the `defs.json` file.
    ```bash
    mix proto_rune.gen.schemas
    ```

2. **Customizable Structs and Typespecs**
    - ProtoRune generates user-friendly typespecs for all query and procedure parameters, ensuring type safety and ease of use.

## Contributing

1. Fork the repository.
2. Create your feature branch (`git checkout -b feature/my-feature`).
3. Commit your changes (`git commit -am 'Add new feature'`).
4. Push to the branch (`git push origin feature/my-feature`).
5. Create a new pull request.

## License

ProtoRune is licensed under the MIT License.
