defmodule Lexicon.App.Bsky.Actor.SearchActorsTest do
  use ExUnit.Case, async: true

  alias Lexicon.App.Bsky.Actor.SearchActors

  describe "validate_params/1" do
    test "validates valid parameters" do
      assert {:ok, params} = SearchActors.validate_params(%{term: "search term"})
      assert params.term == "search term"

      assert {:ok, params} =
               SearchActors.validate_params(%{
                 term: "search term",
                 limit: 20,
                 cursor: "next_page"
               })

      assert params.term == "search term"
      assert params.limit == 20
      assert params.cursor == "next_page"
    end

    test "validates required parameters" do
      assert {:error, changeset} = SearchActors.validate_params(%{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).term
    end

    test "validates term length" do
      # Empty term
      assert {:error, changeset} = SearchActors.validate_params(%{term: ""})
      refute changeset.valid?
      # Just check that there's an error
      assert errors_on(changeset).term

      # Too long term
      long_term = String.duplicate("x", 101)
      assert {:error, changeset} = SearchActors.validate_params(%{term: long_term})
      refute changeset.valid?
      assert "should be at most 100 character(s)" in errors_on(changeset).term
    end

    test "validates limit constraints" do
      # Too small
      assert {:error, changeset} = SearchActors.validate_params(%{term: "search", limit: 0})
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).limit

      # Too large
      assert {:error, changeset} = SearchActors.validate_params(%{term: "search", limit: 101})
      refute changeset.valid?
      assert "must be less than or equal to 100" in errors_on(changeset).limit

      # Just right
      assert {:ok, _} = SearchActors.validate_params(%{term: "search", limit: 100})
    end
  end

  describe "validate_output/1" do
    test "validates output with actors" do
      output = %{
        actors: [
          %{did: "did:plc:1234", handle: "user1.bsky.social"},
          %{did: "did:plc:5678", handle: "user2.bsky.social"}
        ],
        cursor: "next_page"
      }

      assert {:ok, validated} = SearchActors.validate_output(output)
      assert length(validated.actors) == 2
      assert validated.cursor == "next_page"
    end

    test "validates output with empty actors list" do
      output = %{actors: []}

      assert {:ok, validated} = SearchActors.validate_output(output)
      assert validated.actors == []
    end

    test "returns error for missing required fields" do
      assert {:error, changeset} = SearchActors.validate_output(%{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).actors
    end

    test "returns error for invalid actors" do
      # Invalid actor (missing required fields)
      output = %{
        actors: [
          # Missing did and handle
          %{}
        ]
      }

      assert {:error, _} = SearchActors.validate_output(output)
    end
  end

  # Helper functions

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
