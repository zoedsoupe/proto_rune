defmodule Lexicon.App.Bsky.Feed.GetPostThread do
  @moduledoc """
  Query to get a thread of posts.

  NSID: app.bsky.feed.getPostThread
  """

  import Ecto.Changeset

  @param_types %{
    uri: :string,
    depth: :integer
  }

  @output_types %{
    # ThreadViewPost | NotFoundPost | BlockedPost
    thread: :map
  }

  @doc """
  Validates the parameters for getting a post thread.
  """
  def validate_params(params) when is_map(params) do
    {%{}, @param_types}
    |> cast(params, Map.keys(@param_types))
    |> validate_required([:uri])
    |> validate_format(:uri, ~r/^at:/, message: "must be an AT URI")
    |> validate_number(:depth, greater_than_or_equal_to: 0, less_than_or_equal_to: 1000)
    |> apply_action(:validate)
  end

  @doc """
  Validates the output from getting a post thread.
  """
  def validate_output(output) when is_map(output) do
    changeset =
      {%{}, @output_types}
      |> cast(output, Map.keys(@output_types))
      |> validate_required([:thread])

    # Here we would validate the thread structure, but it's complex and could be
    # one of several types, so we'll just validate the basic structure.

    case apply_action(changeset, :validate) do
      {:ok, validated} -> {:ok, validated}
      error -> error
    end
  end
end
