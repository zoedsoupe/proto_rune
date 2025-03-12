defmodule Lexicon.Chat.Bsky.Actor.DeclarationTest do
  use ExUnit.Case, async: true
  
  alias Lexicon.Chat.Bsky.Actor.Declaration

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Declaration.changeset(%Declaration{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).allow_incoming
    end

    test "validates inclusion of allow_incoming" do
      # Valid values
      changeset = Declaration.changeset(%Declaration{}, %{allow_incoming: :all})
      assert changeset.valid?
      
      changeset = Declaration.changeset(%Declaration{}, %{allow_incoming: :none})
      assert changeset.valid?
      
      changeset = Declaration.changeset(%Declaration{}, %{allow_incoming: :following})
      assert changeset.valid?
      
      # Invalid value
      changeset = Declaration.changeset(%Declaration{}, %{allow_incoming: :invalid})
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).allow_incoming
    end
  end

  describe "new/1" do
    test "creates a valid declaration" do
      assert {:ok, declaration} = Declaration.new(%{allow_incoming: :all})
      assert declaration.allow_incoming == :all
    end

    test "returns error with invalid data" do
      assert {:error, changeset} = Declaration.new(%{})
      refute changeset.valid?
    end
  end

  describe "validate/1" do
    test "validates a map against the schema" do
      assert {:ok, declaration} = Declaration.validate(%{allow_incoming: :following})
      assert declaration.allow_incoming == :following
    end

    test "returns error with invalid data" do
      assert {:error, changeset} = Declaration.validate(%{})
      refute changeset.valid?
    end
  end

  # Helper function to extract error messages
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end