defmodule Lexicon.App.Bsky.Graph.Block do
  @moduledoc """
  Record declaring a 'block' relationship against another account.
  NOTE: blocks are public in Bluesky; see blog posts for details.

  NSID: app.bsky.graph.block
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          # DID of account to block
          subject: String.t(),
          created_at: DateTime.t()
        }

  @primary_key false
  embedded_schema do
    field :subject, :string
    field :created_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a block.
  """
  def changeset(block, attrs) do
    block
    |> cast(attrs, [:subject, :created_at])
    |> validate_required([:subject, :created_at])
    |> validate_format(:subject, ~r/^did:/, message: "subject must be a DID")
  end

  @doc """
  Creates a new block with the given attributes.
  """
  def new(attrs \\ %{}) do
    attrs = Map.put_new_lazy(attrs, :created_at, &DateTime.utc_now/0)

    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new block, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, block} -> block
      {:error, changeset} -> raise "Invalid block: #{inspect(changeset.errors)}"
    end
  end
end
