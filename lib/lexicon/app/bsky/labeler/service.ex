defmodule Lexicon.App.Bsky.Labeler.Service do
  @moduledoc """
  A declaration of the existence of a labeler service.

  NSID: app.bsky.labeler.service
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Labeler.Policies

  @type t :: %__MODULE__{
          policies: Policies.t(),
          labels: map() | nil,
          created_at: DateTime.t()
        }

  @primary_key false
  embedded_schema do
    embeds_one :policies, Policies
    field :labels, :map
    field :created_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a labeler service.
  """
  def changeset(service, attrs) do
    service
    |> cast(attrs, [:labels, :created_at])
    |> cast_embed(:policies, required: true)
    |> validate_required([:created_at])
    |> validate_labels()
  end

  defp validate_labels(changeset) do
    if labels = get_field(changeset, :labels) do
      if is_map(labels) and Map.has_key?(labels, :values) do
        values = Map.get(labels, :values)

        if is_list(values) do
          labels_valid =
            Enum.all?(values, fn
              %{val: val} when is_binary(val) -> true
              _ -> false
            end)

          if labels_valid do
            changeset
          else
            add_error(changeset, :labels, "values must all contain a 'val' field")
          end
        else
          add_error(changeset, :labels, "values must be a list")
        end
      else
        add_error(changeset, :labels, "must contain a 'values' field")
      end
    else
      changeset
    end
  end

  @doc """
  Creates a new labeler service with the given attributes.
  """
  def new(attrs \\ %{}) do
    attrs = Map.put_new_lazy(attrs, :created_at, &DateTime.utc_now/0)

    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new labeler service, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, service} -> service
      {:error, changeset} -> raise "Invalid labeler service: #{inspect(changeset.errors)}"
    end
  end
end
