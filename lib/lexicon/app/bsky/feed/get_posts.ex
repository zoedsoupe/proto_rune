defmodule Lexicon.App.Bsky.Feed.GetPosts do
  @moduledoc """
  Query to get posts by URI.

  NSID: app.bsky.feed.getPosts
  """

  import Ecto.Changeset

  @param_types %{
    uris: {:array, :string}
  }

  @output_types %{
    # Array of PostView
    posts: {:array, :map}
  }

  @doc """
  Validates the parameters for getting posts.
  """
  def validate_params(params) when is_map(params) do
    changeset =
      {%{}, @param_types}
      |> cast(params, Map.keys(@param_types))
      |> validate_required([:uris])
      |> validate_length(:uris, min: 1, max: 25)

    # Validate that each URI is properly formatted
    if uris = get_field(changeset, :uris) do
      uris
      |> Enum.reduce(changeset, fn uri, acc ->
        if is_binary(uri) && Regex.match?(~r/^at:/, uri) do
          acc
        else
          add_error(acc, :uris, "must all be AT URIs")
        end
      end)
      |> apply_action(:validate)
    else
      apply_action(changeset, :validate)
    end
  end

  @doc """
  Validates the output from getting posts.
  """
  def validate_output(output) when is_map(output) do
    changeset =
      {%{}, @output_types}
      |> cast(output, Map.keys(@output_types))
      |> validate_required([:posts])

    # Here we would validate each post view, but that's complex,
    # so we'll just validate the basic structure.

    case apply_action(changeset, :validate) do
      {:ok, validated} -> {:ok, validated}
      error -> error
    end
  end
end
