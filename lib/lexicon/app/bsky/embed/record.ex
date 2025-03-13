defmodule Lexicon.App.Bsky.Embed.Record do
  @moduledoc """
  A representation of a record embedded in a Bluesky record (eg, a post).
  For example, a quote-post, or sharing a feed generator record.

  NSID: app.bsky.embed.record
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          # com.atproto.repo.strongRef
          record: map()
        }

  @primary_key false
  embedded_schema do
    field :record, :map
  end

  @doc """
  Creates a changeset for validating a record embed.
  """
  def changeset(record, attrs) do
    record
    |> cast(attrs, [:record])
    |> validate_required([:record])
    |> validate_record()
  end

  defp validate_record(changeset) do
    if record = get_field(changeset, :record) do
      cond do
        not is_map(record) ->
          add_error(changeset, :record, "must be a map")

        not Map.has_key?(record, :uri) ->
          add_error(changeset, :record, "must have a URI")

        not Map.has_key?(record, :cid) ->
          add_error(changeset, :record, "must have a CID")

        true ->
          # Validate URI format
          uri = Map.get(record, :uri)

          if not is_binary(uri) or not String.match?(uri, ~r/^at:\/\//) do
            add_error(changeset, :record, "must have a valid AT-URI")
          else
            changeset
          end
      end
    else
      changeset
    end
  end

  @doc """
  Creates a new record embed with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new record embed, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, record} -> record
      {:error, changeset} -> raise "Invalid record embed: #{inspect(changeset.errors)}"
    end
  end
end
