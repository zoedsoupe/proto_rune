defmodule Lexicon.App.Bsky.Unspecced.TrendView do
  @moduledoc """
  A view of a trend with full information.

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
          actors: [map()]
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
    # Array of app.bsky.actor.defs#profileViewBasic
    field :actors, {:array, :map}
  end

  @doc """
  Creates a changeset for validating a trend view.
  """
  def changeset(trend_view, attrs) do
    trend_view
    |> cast(attrs, [:topic, :display_name, :link, :started_at, :post_count, :status, :category, :actors])
    |> validate_required([:topic, :display_name, :link, :started_at, :post_count, :actors])
    |> validate_number(:post_count, greater_than_or_equal_to: 0)
    |> validate_trend_status()
  end

  defp validate_trend_status(changeset) do
    status = get_field(changeset, :status)

    if status && !Unspecced.valid_trend_status?(status) do
      add_error(changeset, :status, "must be a valid trend status")
    else
      changeset
    end
  end

  @doc """
  Validates a trend view structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
