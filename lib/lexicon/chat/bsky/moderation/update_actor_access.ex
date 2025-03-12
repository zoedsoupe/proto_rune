defmodule Lexicon.Chat.Bsky.Moderation.UpdateActorAccess do
  @moduledoc """
  Procedure to update an actor's access for moderation purposes.

  NSID: chat.bsky.moderation.updateActorAccess
  """

  import Ecto.Changeset

  @input_types %{
    actor: :string,
    allow_access: :boolean,
    ref: :string
  }

  @doc """
  Validates the input for updating actor access.
  """
  def validate_input(input) when is_map(input) do
    {%{}, @input_types}
    |> cast(input, Map.keys(@input_types))
    |> validate_required([:actor, :allow_access])
    |> validate_format(:actor, ~r/^did:/)
    |> apply_action(:validate)
  end

  @doc """
  This procedure has no output.
  """
  def validate_output(nil), do: {:ok, nil}
end