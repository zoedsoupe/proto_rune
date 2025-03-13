defmodule Lexicon.App.Bsky.Labeler.PoliciesTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Labeler.Policies

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Policies.changeset(%Policies{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).label_values
    end

    test "validates label_values format" do
      # Valid label values
      changeset =
        Policies.changeset(%Policies{}, %{
          label_values: [
            %{val: "nsfw"},
            %{val: "spam"}
          ]
        })

      assert changeset.valid?

      # Test with direct changeset creation for invalid values
      changeset =
        %Policies{}
        |> Ecto.Changeset.cast(%{label_values: "not-a-list"}, [:label_values])
        |> Policies.validate_label_values_for_test()

      assert "must be a list" in errors_on(changeset).label_values

      # Test invalid label values for missing val field
      changeset =
        Policies.changeset(%Policies{}, %{
          label_values: [
            %{invalid: "field"},
            %{another: "invalid"}
          ]
        })

      refute changeset.valid?
      assert "must all be valid label values with a 'val' field" in errors_on(changeset).label_values
    end

    test "validates label_value_definitions format" do
      # Valid with basic label values
      changeset =
        Policies.changeset(%Policies{}, %{
          label_values: [%{val: "nsfw"}]
        })

      assert changeset.valid?

      # Valid with label value definitions
      changeset =
        Policies.changeset(%Policies{}, %{
          label_values: [%{val: "nsfw"}],
          label_value_definitions: [
            %{
              identifier: "nsfw",
              blurs: ["content", "thumbnail"],
              severity: "alert"
            }
          ]
        })

      assert changeset.valid?

      # Test with direct changeset creation for invalid values
      changeset =
        %Policies{}
        |> Ecto.Changeset.cast(
          %{
            label_values: [%{val: "nsfw"}],
            label_value_definitions: "not-a-list"
          },
          [:label_values, :label_value_definitions]
        )
        |> Policies.validate_label_value_definitions_for_test()

      assert "must be a list" in errors_on(changeset).label_value_definitions

      # Test invalid label value definitions
      changeset =
        Policies.changeset(%Policies{}, %{
          label_values: [%{val: "nsfw"}],
          label_value_definitions: [
            %{identifier: "missing-fields"}
          ]
        })

      refute changeset.valid?
      assert "must all be valid label value definitions" in errors_on(changeset).label_value_definitions
    end
  end

  describe "new/1" do
    test "creates valid policies with only label_values" do
      label_values = [%{val: "nsfw"}, %{val: "spam"}]

      assert {:ok, policies} =
               Policies.new(%{
                 label_values: label_values
               })

      assert policies.label_values == label_values
      assert policies.label_value_definitions == nil
    end

    test "creates valid policies with all fields" do
      label_values = [%{val: "nsfw"}, %{val: "spam"}]

      label_value_definitions = [
        %{
          identifier: "nsfw",
          blurs: ["content", "thumbnail"],
          severity: "alert"
        }
      ]

      assert {:ok, policies} =
               Policies.new(%{
                 label_values: label_values,
                 label_value_definitions: label_value_definitions
               })

      assert policies.label_values == label_values
      assert policies.label_value_definitions == label_value_definitions
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = Policies.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates valid policies" do
      label_values = [%{val: "nsfw"}, %{val: "spam"}]

      assert %Policies{} =
               policies =
               Policies.new!(%{
                 label_values: label_values
               })

      assert policies.label_values == label_values
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid labeler policies/, fn ->
        Policies.new!(%{})
      end
    end
  end
end
