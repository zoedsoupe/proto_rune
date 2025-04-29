defmodule Lexicon.App.Bsky.Actor.Defs.HiddenPostsPref do
  @moduledoc """
  Preferences for hidden posts.

  Part of app.bsky.actor.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          items: [String.t()]
        }

  @primary_key false
  embedded_schema do
    field :items, {:array, :string}
  end

  @doc """
  Creates a changeset for validating hidden posts preferences.
  """
  def changeset(pref, attrs) do
    pref
    |> cast(attrs, [:items])
    |> validate_required([:items])
    |> validate_at_uris()
  end

  defp validate_at_uris(changeset) do
    uris = get_field(changeset, :items)

    if uris do
      # Validate each URI in the array
      invalid_uris = Enum.filter(uris, fn uri -> !String.match?(uri, ~r/^at:\/\//) end)

      if Enum.empty?(invalid_uris) do
        changeset
      else
        add_error(changeset, :items, "contains invalid AT-URIs")
      end
    else
      changeset
    end
  end

  @doc """
  Validates a hidden posts preferences structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
