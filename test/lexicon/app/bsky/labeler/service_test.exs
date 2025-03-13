defmodule Lexicon.App.Bsky.Labeler.ServiceTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Labeler.Policies
  alias Lexicon.App.Bsky.Labeler.Service

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Service.changeset(%Service{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).policies
      assert "can't be blank" in errors_on(changeset).created_at
    end

    test "validates policies" do
      # Valid policies
      changeset =
        Service.changeset(%Service{}, %{
          policies: %{
            label_values: [%{val: "nsfw"}]
          },
          created_at: DateTime.utc_now()
        })

      assert changeset.valid?

      # Invalid policies
      changeset =
        Service.changeset(%Service{}, %{
          policies: %{},
          created_at: DateTime.utc_now()
        })

      refute changeset.valid?
    end

    test "validates labels format" do
      valid_attrs = %{
        policies: %{
          label_values: [%{val: "nsfw"}]
        },
        created_at: DateTime.utc_now()
      }

      # Valid labels
      changeset =
        Service.changeset(
          %Service{},
          Map.put(valid_attrs, :labels, %{
            values: [%{val: "self-label"}]
          })
        )

      assert changeset.valid?

      # Invalid - missing values field
      changeset =
        Service.changeset(
          %Service{},
          Map.put(valid_attrs, :labels, %{
            other: "field"
          })
        )

      refute changeset.valid?
      assert "must contain a 'values' field" in errors_on(changeset).labels

      # Invalid - values not a list
      changeset =
        Service.changeset(
          %Service{},
          Map.put(valid_attrs, :labels, %{
            values: "not-a-list"
          })
        )

      refute changeset.valid?
      assert "values must be a list" in errors_on(changeset).labels

      # Invalid - values missing val field
      changeset =
        Service.changeset(
          %Service{},
          Map.put(valid_attrs, :labels, %{
            values: [%{invalid: "field"}]
          })
        )

      refute changeset.valid?
      assert "values must all contain a 'val' field" in errors_on(changeset).labels
    end
  end

  describe "new/1" do
    test "creates a valid service without labels" do
      policies_data = %{
        label_values: [%{val: "nsfw"}, %{val: "spam"}]
      }

      created_at = DateTime.truncate(DateTime.utc_now(), :second)

      assert {:ok, service} =
               Service.new(%{
                 policies: policies_data,
                 created_at: created_at
               })

      assert %Policies{} = service.policies
      assert service.policies.label_values == policies_data.label_values
      assert service.labels == nil
      assert service.created_at == created_at
    end

    test "creates a valid service with labels" do
      policies_data = %{
        label_values: [%{val: "nsfw"}]
      }

      labels_data = %{
        values: [%{val: "self-label"}]
      }

      assert {:ok, service} =
               Service.new(%{
                 policies: policies_data,
                 labels: labels_data
               })

      assert %Policies{} = service.policies
      assert service.labels == labels_data
      assert %DateTime{} = service.created_at
    end

    test "sets created_at automatically" do
      policies_data = %{
        label_values: [%{val: "nsfw"}]
      }

      assert {:ok, service} =
               Service.new(%{
                 policies: policies_data
               })

      assert %DateTime{} = service.created_at
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = Service.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid service" do
      policies_data = %{
        label_values: [%{val: "nsfw"}]
      }

      assert %Service{} =
               service =
               Service.new!(%{
                 policies: policies_data
               })

      assert %Policies{} = service.policies
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid labeler service/, fn ->
        Service.new!(%{})
      end
    end
  end
end
