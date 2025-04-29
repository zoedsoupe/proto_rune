defmodule Lexicon.Com.Atproto.Label.SelfLabels do
  @moduledoc """
  Metadata tags on an atproto record, published by the author within the record.

  NSID: com.atproto.label.defs#selfLabels
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.Com.Atproto.Label.SelfLabel

  @type t :: %__MODULE__{
          values: [SelfLabel.t()]
        }

  @primary_key false
  embedded_schema do
    embeds_many :values, SelfLabel
  end

  @doc """
  Creates a changeset for validating self labels.
  """
  def changeset(self_labels, attrs) do
    self_labels
    |> cast(attrs, [])
    |> cast_embed(:values, required: true)
    |> validate_length(:values, max: 10)
  end

  @doc """
  Creates new self labels with the given attributes.
  """
  def new(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates new self labels with the given attributes, raises on error.
  """
  def new!(attrs) do
    case new(attrs) do
      {:ok, self_labels} -> self_labels
      {:error, changeset} -> raise Ecto.InvalidChangesetError, changeset: changeset
    end
  end

  @doc """
  Validates a self labels structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
