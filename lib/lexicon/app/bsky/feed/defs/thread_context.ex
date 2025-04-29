defmodule Lexicon.App.Bsky.Feed.Defs.ThreadContext do
  @moduledoc """
  Metadata about this post within the context of the thread it is in.

  Part of app.bsky.feed.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          root_author_like: String.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :root_author_like, :string
  end

  @doc """
  Creates a changeset for validating a thread context.
  """
  def changeset(thread_context, attrs) do
    cast(thread_context, attrs, [:root_author_like])
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
