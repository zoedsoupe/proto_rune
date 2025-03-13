defmodule Lexicon.Chat.Bsky.Actor.Declaration do
  @moduledoc """
  A declaration of a Bluesky chat account.

  NSID: chat.bsky.actor.declaration
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type allow_incoming_option :: :all | :none | :following
  @type t :: %__MODULE__{
          allow_incoming: allow_incoming_option()
        }

  @primary_key false
  embedded_schema do
    field :allow_incoming, Ecto.Enum, values: [:all, :none, :following]
  end

  @doc """
  Creates a changeset for validating the declaration.
  """
  def changeset(declaration, attrs) do
    declaration
    |> cast(attrs, [:allow_incoming])
    |> validate_required([:allow_incoming])
  end

  @doc """
  Creates a new declaration with the given attributes.

  ## Examples

      iex> Declaration.new(%{allow_incoming: :following})
      {:ok, %Declaration{allow_incoming: :following}}
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Validates a declaration structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
