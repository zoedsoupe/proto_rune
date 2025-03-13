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
    case get_field(changeset, :record) do
      nil ->
        changeset

      record when not is_map(record) ->
        add_error(changeset, :record, "must be a map")

      record ->
        validate_record_fields(changeset, record)
    end
  end

  defp validate_record_fields(changeset, record) do
    changeset
    |> validate_record_has_uri(record)
    |> validate_record_has_cid(record)
    |> validate_record_uri_format(record)
  end

  defp validate_record_has_uri(changeset, record) do
    if Map.has_key?(record, :uri) do
      changeset
    else
      add_error(changeset, :record, "must have a URI")
    end
  end

  defp validate_record_has_cid(changeset, record) do
    if Map.has_key?(record, :cid) do
      changeset
    else
      add_error(changeset, :record, "must have a CID")
    end
  end

  defp validate_record_uri_format(changeset, %{uri: uri}) do
    if is_binary(uri) and String.match?(uri, ~r/^at:\/\//) do
      changeset
    else
      add_error(changeset, :record, "must have a valid AT-URI")
    end
  end

  defp validate_record_uri_format(changeset, _), do: changeset

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
