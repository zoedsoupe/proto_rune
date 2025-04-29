defmodule Lexicon.App.Bsky.Unspecced.SkeletonTrend do
  @moduledoc """
  A skeleton trend with minimal information.

  Part of app.bsky.unspecced lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Unspecced

  @type t :: %__MODULE__{
          topic: String.t(),
          display_name: String.t(),
          link: String.t(),
          started_at: DateTime.t(),
          post_count: integer(),
          status: String.t() | nil,
          category: String.t() | nil,
          dids: [String.t()]
        }

  @primary_key false
  embedded_schema do
    field :topic, :string
    field :display_name, :string
    field :link, :string
    field :started_at, :utc_datetime
    field :post_count, :integer
    field :status, :string
    field :category, :string
    field :dids, {:array, :string}
  end

  @doc """
  Creates a changeset for validating a skeleton trend.
  """
  def changeset(skeleton_trend, attrs) do
    skeleton_trend
    |> cast(attrs, [:topic, :display_name, :link, :started_at, :post_count, :status, :category, :dids])
    |> validate_required([:topic, :display_name, :link, :started_at, :post_count, :dids])
    |> validate_number(:post_count, greater_than_or_equal_to: 0)
    |> validate_trend_status()
    |> validate_dids()
  end

  defp validate_trend_status(changeset) do
    status = get_field(changeset, :status)

    if status && !Unspecced.valid_trend_status?(status) do
      add_error(changeset, :status, "must be a valid trend status")
    else
      changeset
    end
  end

  defp validate_dids(changeset) do
    dids = get_field(changeset, :dids)

    if dids do
      # Validate each DID in the array
      invalid_dids = Enum.filter(dids, fn did -> !String.match?(did, ~r/^did:/) end)

      if Enum.empty?(invalid_dids) do
        changeset
      else
        add_error(changeset, :dids, "contains invalid DIDs")
      end
    else
      changeset
    end
  end

  @doc """
  Validates a skeleton trend structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
