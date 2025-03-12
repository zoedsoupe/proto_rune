defmodule Lexicon.App.Bsky.Feed.ThreadContext do
  @moduledoc """
  Metadata about a post within the context of its thread.

  NSID: app.bsky.feed.defs#threadContext
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
    root_author_like: String.t() | nil
  }

  @primary_key false
  embedded_schema do
    field :root_author_like, :string # format: at-uri
  end

  @doc """
  Creates a changeset for validating thread context.
  """
  def changeset(thread_context, attrs) do
    thread_context
    |> cast(attrs, [:root_author_like])
    |> validate_format(:root_author_like, ~r/^at:/, message: "must be an AT URI")
  end

  @doc """
  Validates a thread context structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end