defmodule Lexicon.App.Bsky.Actor.SavedFeedsPref do
  @moduledoc """
  Preferences for saved feeds.

  Part of app.bsky.actor lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          pinned: [String.t()],
          saved: [String.t()],
          timeline_index: integer() | nil
        }

  @primary_key false
  embedded_schema do
    field :pinned, {:array, :string}
    field :saved, {:array, :string}
    field :timeline_index, :integer
  end

  @doc """
  Creates a changeset for validating saved feeds preferences.
  """
  def changeset(pref, attrs) do
    pref
    |> cast(attrs, [:pinned, :saved, :timeline_index])
    |> validate_required([:pinned, :saved])
    |> validate_at_uris(:pinned)
    |> validate_at_uris(:saved)
  end

  defp validate_at_uris(changeset, field) do
    uris = get_field(changeset, field)

    if uris do
      # Validate each URI in the array
      invalid_uris = Enum.filter(uris, fn uri -> !String.match?(uri, ~r/^at:\/\//) end)

      if Enum.empty?(invalid_uris) do
        changeset
      else
        add_error(changeset, field, "contains invalid AT-URIs")
      end
    else
      changeset
    end
  end

  @doc """
  Validates a saved feeds preferences structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
