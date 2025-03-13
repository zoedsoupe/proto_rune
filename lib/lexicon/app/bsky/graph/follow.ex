defmodule Lexicon.App.Bsky.Graph.Follow do
  @moduledoc """
  Record declaring a social 'follow' relationship of another account.
  Duplicate follows will be ignored by the AppView.

  NSID: app.bsky.graph.follow
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          # DID of account to follow
          subject: String.t(),
          created_at: DateTime.t()
        }

  @primary_key false
  embedded_schema do
    field :subject, :string
    field :created_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a follow.
  """
  def changeset(follow, attrs) do
    follow
    |> cast(attrs, [:subject, :created_at])
    |> validate_required([:subject, :created_at])
    |> validate_format(:subject, ~r/^did:/, message: "subject must be a DID")
  end

  @doc """
  Creates a new follow with the given attributes.
  """
  def new(attrs \\ %{}) do
    attrs = Map.put_new_lazy(attrs, :created_at, &DateTime.utc_now/0)

    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new follow, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, follow} -> follow
      {:error, changeset} -> raise "Invalid follow: #{inspect(changeset.errors)}"
    end
  end
end
