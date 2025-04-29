defmodule Lexicon.App.Bsky.Actor.PostInteractionSettingsPref do
  @moduledoc """
  Default post interaction settings for the account.

  Part of app.bsky.actor lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          threadgate_allow_rules: [map()] | nil,
          postgate_embedding_rules: [map()] | nil
        }

  @primary_key false
  embedded_schema do
    field :threadgate_allow_rules, {:array, :map}
    field :postgate_embedding_rules, {:array, :map}
  end

  @doc """
  Creates a changeset for validating post interaction settings preferences.
  """
  def changeset(pref, attrs) do
    pref
    |> cast(attrs, [:threadgate_allow_rules, :postgate_embedding_rules])
    |> validate_length(:threadgate_allow_rules, max: 5)
    |> validate_length(:postgate_embedding_rules, max: 5)
  end

  @doc """
  Validates a post interaction settings preferences structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
