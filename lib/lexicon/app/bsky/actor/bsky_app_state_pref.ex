defmodule Lexicon.App.Bsky.Actor.BskyAppStatePref do
  @moduledoc """
  A grab bag of state that's specific to the bsky.app program.

  Part of app.bsky.actor lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Actor.BskyAppProgressGuide
  alias Lexicon.App.Bsky.Actor.Nux

  @type t :: %__MODULE__{
          active_progress_guide: BskyAppProgressGuide.t() | nil,
          queued_nudges: [String.t()] | nil,
          nuxs: [Nux.t()] | nil
        }

  @primary_key false
  embedded_schema do
    embeds_one :active_progress_guide, BskyAppProgressGuide
    field :queued_nudges, {:array, :string}
    embeds_many :nuxs, Nux
  end

  @doc """
  Creates a changeset for validating Bluesky app state preferences.
  """
  def changeset(pref, attrs) do
    pref
    |> cast(attrs, [:queued_nudges])
    |> cast_embed(:active_progress_guide)
    |> cast_embed(:nuxs)
    |> validate_length(:queued_nudges, max: 1000)
    |> validate_nudge_lengths()
  end

  defp validate_nudge_lengths(changeset) do
    nudges = get_field(changeset, :queued_nudges)

    if nudges do
      invalid_nudges = Enum.filter(nudges, fn nudge -> String.length(nudge) > 100 end)

      if Enum.empty?(invalid_nudges) do
        changeset
      else
        add_error(changeset, :queued_nudges, "contains nudges that exceed maximum length")
      end
    else
      changeset
    end
  end

  @doc """
  Validates a Bluesky app state preferences structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
