defmodule Lexicon.App.Bsky.Feed.Repost do
  @moduledoc """
  Record representing a 'repost' of an existing Bluesky post.

  NSID: app.bsky.feed.repost
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          # com.atproto.repo.strongRef
          subject: map(),
          created_at: DateTime.t()
        }

  @primary_key false
  embedded_schema do
    # Reference to com.atproto.repo.strongRef
    field :subject, :map
    field :created_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a repost.
  """
  def changeset(repost, attrs) do
    repost
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
  Creates a new repost with the given attributes.
  """
  def new(attrs \\ %{}) do
    attrs = Map.put_new_lazy(attrs, :created_at, &DateTime.utc_now/0)

    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new repost, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, repost} -> repost
      {:error, changeset} -> raise "Invalid repost: #{inspect(changeset.errors)}"
    end
  end
end
