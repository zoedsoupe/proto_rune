defmodule Lexicon.App.Bsky.Richtext.ByteSlice do
  @moduledoc """
  Specifies the sub-string range a facet feature applies to.
  Start index is inclusive, end index is exclusive.
  Indices are zero-indexed, counting bytes of the UTF-8 encoded text.

  NSID: app.bsky.richtext.facet#byteSlice
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          byte_start: non_neg_integer(),
          byte_end: non_neg_integer()
        }

  @primary_key false
  embedded_schema do
    field :byte_start, :integer
    field :byte_end, :integer
  end

  @doc """
  Creates a changeset for validating a byte slice.
  """
  def changeset(byte_slice, attrs) do
    byte_slice
    |> cast(attrs, [:byte_start, :byte_end])
    |> validate_required([:byte_start, :byte_end])
    |> validate_number(:byte_start, greater_than_or_equal_to: 0)
    |> validate_number(:byte_end, greater_than_or_equal_to: 0)
    |> validate_byte_slice()
  end

  defp validate_byte_slice(changeset) do
    byte_start = get_field(changeset, :byte_start)
    byte_end = get_field(changeset, :byte_end)

    if is_integer(byte_start) and is_integer(byte_end) and byte_start > byte_end do
      add_error(changeset, :byte_end, "must be greater than or equal to byte_start")
    else
      changeset
    end
  end

  @doc """
  Creates a new byte slice with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new byte slice, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, byte_slice} -> byte_slice
      {:error, changeset} -> raise "Invalid byte slice: #{inspect(changeset.errors)}"
    end
  end
end
