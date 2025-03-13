defmodule Lexicon.App.Bsky.Graph.Listitem do
  @moduledoc """
  Record representing an account's inclusion on a specific list.
  The AppView will ignore duplicate listitem records.

  NSID: app.bsky.graph.listitem
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          subject: String.t(),
          list: String.t(),
          created_at: DateTime.t()
        }

  @primary_key false
  embedded_schema do
    field :subject, :string
    field :list, :string
    field :created_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a list item.
  """
  def changeset(listitem, attrs) do
    listitem
    |> cast(attrs, [:subject, :list, :created_at])
    |> validate_required([:subject, :list, :created_at])
    |> validate_format(:subject, ~r/^did:/, message: "subject must be a DID")
    |> validate_format(:list, ~r/^at:\/\//, message: "list must be an AT-URI")
  end

  @doc """
  Creates a new list item with the given attributes.
  """
  def new(attrs \\ %{}) do
    attrs = Map.put_new_lazy(attrs, :created_at, &DateTime.utc_now/0)

    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new list item, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, listitem} -> listitem
      {:error, changeset} -> raise "Invalid list item: #{inspect(changeset.errors)}"
    end
  end
end
