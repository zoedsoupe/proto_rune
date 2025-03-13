defmodule Lexicon.Chat.Bsky.Convo.ListConvosTest do
  use ExUnit.Case, async: true

  alias Lexicon.Chat.Bsky.Convo.ListConvos

  describe "validate_params/1" do
    test "validates empty params (uses defaults)" do
      assert {:ok, validated} = ListConvos.validate_params(%{})
      assert validated == %{}
    end

    test "validates valid params" do
      params = %{
        limit: 20,
        cursor: "next_page"
      }

      assert {:ok, validated} = ListConvos.validate_params(params)
      assert validated.limit == 20
      assert validated.cursor == "next_page"
    end

    test "validates limit constraints" do
      # Too small
      assert {:error, changeset} = ListConvos.validate_params(%{limit: 0})
      assert "must be greater than 0" in errors_on(changeset).limit

      # Too large
      assert {:error, changeset} = ListConvos.validate_params(%{limit: 101})
      assert "must be less than or equal to 100" in errors_on(changeset).limit

      # Just right
      assert {:ok, validated} = ListConvos.validate_params(%{limit: 100})
      assert validated.limit == 100
    end
  end

  describe "validate_output/1" do
    test "validates valid output" do
      output = %{
        cursor: "next_page",
        convos: [
          %{
            id: "convo123",
            rev: "rev1",
            members: [
              %{did: "did:plc:1234", handle: "user1.bsky.social"}
            ],
            muted: false,
            unread_count: 0
          }
        ]
      }

      assert {:ok, validated} = ListConvos.validate_output(output)
      assert validated.cursor == "next_page"
      assert length(validated.convos) == 1
      assert hd(validated.convos).id == "convo123"
    end

    test "validates output with empty convos list" do
      output = %{
        cursor: "next_page",
        convos: []
      }

      assert {:ok, validated} = ListConvos.validate_output(output)
      assert validated.cursor == "next_page"
      assert validated.convos == []
    end

    test "returns error for missing required fields" do
      # Missing convos
      assert {:error, changeset} =
               ListConvos.validate_output(%{
                 cursor: "next_page"
               })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).convos
    end

    test "returns error for invalid convo in the list" do
      # Invalid convo (missing required fields)
      output = %{
        cursor: "next_page",
        convos: [
          # Missing rev, members, muted, unread_count
          %{id: "convo123"}
        ]
      }

      assert {:error, _} = ListConvos.validate_output(output)
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
