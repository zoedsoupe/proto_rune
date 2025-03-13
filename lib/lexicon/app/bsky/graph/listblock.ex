defmodule Lexicon.App.Bsky.Graph.Listblock do
  @moduledoc """
  Record indicating that a specific account (actor) is blocking
  a specific list of accounts (actors).

  NSID: app.bsky.graph.listblock
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          subject: String.t(),
          created_at: DateTime.t()
        }

  @primary_key false
  embedded_schema do
    field :subject, :string
    field :created_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a list block.
  """
  def changeset(listblock, attrs) do
    listblock
    |> cast(attrs, [:subject, :created_at])
    |> validate_required([:subject, :created_at])
    |> validate_format(:subject, ~r/^at:\/\//, message: "subject must be an AT-URI")
  end

  @doc """
  Creates a new list block with the given attributes.
  """
  def new(attrs \\ %{}) do
    attrs = Map.put_new_lazy(attrs, :created_at, &DateTime.utc_now/0)

    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new list block, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, listblock} -> listblock
      {:error, changeset} -> raise "Invalid list block: #{inspect(changeset.errors)}"
    end
  end
end
