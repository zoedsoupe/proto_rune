defmodule ProtoRune.Lexicon do
  @moduledoc """
  Type definitions for the Intermediate Representation (IR) of AT Protocol Lexicons.
  This structure serves as a bridge between raw lexicon JSON and generated Elixir code.
  """

  @type t :: %{
          # Lexicon schema version
          lexicon: integer,
          # Original lexicon NSID (e.g., "app.bsky.feed.post")
          id: String.t(),
          # Optional description of the lexicon
          description: String.t() | nil,
          # Main type of the lexicon definition
          type: definition_type(),
          # Generated Elixir module path
          module_path: module_path(),
          # All type definitions in this lexicon
          definitions: %{
            required(String.t()) => definition()
          }
        }

  # e.g., ["App", "Bsky", "Feed", "Post"]
  @type module_path :: [String.t()]

  @type definition_type :: :record | :object | :query | :procedure

  @type definition :: record() | object() | query() | procedure() | subscription()

  @type record :: %{
          type: :record,
          # Record key type (e.g., "tid")
          key: key_type(),
          # Record fields
          fields: [field()],
          # Required field names
          required: [String.t()],
          # Optional description
          description: String.t() | nil
        }

  @type key_type :: :tid | :literal | :nsid | :any

  @type object :: %{
          type: :object,
          fields: [field()],
          required: [String.t()],
          description: String.t() | nil
        }

  @type field :: {
          # Field name
          name :: String.t(),
          # Field type information
          type :: field_type(),
          # Optional field description
          description :: String.t() | nil
        }

  @type field_type ::
          primitive_type()
          | array_type()
          | union_type()
          | reference_type()

  @type primitive_type ::
          {:string, string_constraints()}
          | {:integer, number_constraints()}
          | {:boolean, []}
          | {:datetime, []}

  @type string_constraints :: [
          {:max_length, pos_integer()}
          | {:max_graphemes, pos_integer()}
          | {:format, string_format()}
        ]

  @type string_format :: :datetime | :language | :did | :handle | :at_uri | :nsid

  @type number_constraints :: [
          {:minimum, number()}
          | {:maximum, number()}
        ]

  @type array_type ::
          {:array,
           type: field_type(),
           constraints: [
             {:max_length, pos_integer()}
           ]}

  @type union_type :: {:union, types: [reference_type()], description: String.t() | nil}

  # Reference to local definition
  @type reference_type ::
          {:ref, local_ref :: String.t()}
          # Reference to external lexicon
          | {:ref, external_ref :: {:lexicon, String.t()}}

  @type io :: %{
          encoding: String.t(),
          description: String.t() | nil,
          schema: object() | reference_type() | union_type()
        }

  @type parameters :: %{
          type: :params,
          required: [String.t()],
          props: [field()]
        }

  @type error :: %{name: String.t(), description: String.t() | nil}

  @type query :: %{
          parameters: parameters() | nil,
          output: io() | nil,
          errors: [error()]
        }

  @type procedure :: %{
          parameters: parameters() | nil,
          output: io() | nil,
          input: io() | nil,
          errors: [error()]
        }

  @type subscription :: %{
          parameters: parameters(),
          errors: [error()],
          message: %{
            schema: union_type(),
            description: String.t() | nil
          }
        }
end
