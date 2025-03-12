defmodule Lexicon.App.Bsky.Feed.Like do
  @moduledoc """
  Record declaring a 'like' of a piece of subject content.

  NSID: app.bsky.feed.like
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
    subject: map(), # com.atproto.repo.strongRef
    created_at: DateTime.t()
  }

  @primary_key false
  embedded_schema do
    field :subject, :map # Reference to com.atproto.repo.strongRef
    field :created_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a like.
  """
  def changeset(like, attrs) do
    like
    |> cast(attrs, [:subject, :created_at])
    |> validate_required([:subject, :created_at])
    |> validate_subject()
  end

  defp validate_subject(changeset) do
    if subject = get_field(changeset, :subject) do
      cond do
        not is_map(subject) ->
          add_error(changeset, :subject, "must be a map")
        not Map.has_key?(subject, :uri) ->
          add_error(changeset, :subject, "must have a URI")
        not Map.has_key?(subject, :cid) ->
          add_error(changeset, :subject, "must have a CID")
        true ->
          changeset
      end
    else
      changeset
    end
  end

  @doc """
  Creates a new like with the given attributes.
  """
  def new(attrs \\ %{}) do
    attrs = Map.put_new_lazy(attrs, :created_at, &DateTime.utc_now/0)
    
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new like, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, like} -> like
      {:error, changeset} -> raise "Invalid like: #{inspect(changeset.errors)}"
    end
  end
end