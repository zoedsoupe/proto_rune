defmodule Lexicon.App.Bsky.Feed.GetTimeline do
  @moduledoc """
  Query to get a view of the requesting account's home timeline.

  NSID: app.bsky.feed.getTimeline
  """

  import Ecto.Changeset

  @param_types %{
    algorithm: :string,
    limit: :integer,
    cursor: :string
  }

  @output_types %{
    cursor: :string,
    # Array of FeedViewPost
    feed: {:array, :map}
  }

  @doc """
  Validates the parameters for getting a timeline.
  """
  def validate_params(params) when is_map(params) do
    {%{}, @param_types}
    |> cast(params, Map.keys(@param_types))
    |> validate_number(:limit, greater_than: 0, less_than_or_equal_to: 100)
    |> apply_action(:validate)
  end

  @doc """
  Validates the output from getting a timeline.
  """
  def validate_output(output) when is_map(output) do
    changeset =
      {%{}, @output_types}
      |> cast(output, Map.keys(@output_types))
      |> validate_required([:feed])

    # Here we could validate each feed item, but that would be complex
    # since each item is a FeedViewPost with nested structures.
    # For simplicity, we'll just validate the basic structure.

    case apply_action(changeset, :validate) do
      {:ok, validated} -> {:ok, validated}
      error -> error
    end
  end
end
