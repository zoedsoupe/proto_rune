defmodule Lexicon.Com.Atproto.Label.LabelValueDefinition do
  @moduledoc """
  Declares a label value and its expected interpretations and behaviors.

  NSID: com.atproto.label.defs#labelValueDefinition
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.Com.Atproto.Label.Defs
  alias Lexicon.Com.Atproto.Label.LabelValueDefinitionStrings

  @type t :: %__MODULE__{
          identifier: String.t(),
          severity: String.t(),
          blurs: String.t(),
          default_setting: String.t() | nil,
          adult_only: boolean() | nil,
          locales: [LabelValueDefinitionStrings.t()]
        }

  @primary_key false
  embedded_schema do
    field :identifier, :string
    field :severity, :string
    field :blurs, :string
    field :default_setting, :string, default: "warn"
    field :adult_only, :boolean, default: false
    embeds_many :locales, LabelValueDefinitionStrings
  end

  @doc """
  Creates a changeset for validating a label value definition.
  """
  def changeset(definition, attrs) do
    definition
    |> cast(attrs, [:identifier, :severity, :blurs, :default_setting, :adult_only])
    |> validate_required([:identifier, :severity, :blurs, :locales])
    |> validate_length(:identifier, max: 100)
    |> validate_format(:identifier, ~r/^[a-z-]+$/, message: "must only include lowercase ascii and '-'")
    |> validate_inclusion(:severity, [Defs.severity_inform(), Defs.severity_alert(), Defs.severity_none()])
    |> validate_inclusion(:blurs, [Defs.blur_content(), Defs.blur_media(), Defs.blur_none()])
    |> validate_inclusion(:default_setting, [
      Defs.default_setting_ignore(),
      Defs.default_setting_warn(),
      Defs.default_setting_hide()
    ])
    |> cast_embed(:locales, required: true)
  end

  @doc """
  Creates a new label value definition with the given attributes.
  """
  def new(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new label value definition with the given attributes, raises on error.
  """
  def new!(attrs) do
    case new(attrs) do
      {:ok, definition} -> definition
      {:error, changeset} -> raise Ecto.InvalidChangesetError, changeset: changeset
    end
  end

  @doc """
  Validates a label value definition structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
