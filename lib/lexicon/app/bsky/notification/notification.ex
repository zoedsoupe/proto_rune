defmodule Lexicon.App.Bsky.Notification.Notification do
  @moduledoc """
  Represents a notification for a user in Bluesky.

  NSID: app.bsky.notification.listNotifications#notification
  """

  use Ecto.Schema

  import Ecto.Changeset

  @valid_reasons ~w(like repost follow mention reply quote starterpack-joined)

  @type t :: %__MODULE__{
          uri: String.t(),
          cid: String.t(),
          # app.bsky.actor.defs#profileView
          author: map(),
          reason: String.t(),
          reason_subject: String.t() | nil,
          # unknown record type
          record: map(),
          is_read: boolean(),
          indexed_at: DateTime.t(),
          labels: list(map()) | nil
        }

  @primary_key false
  embedded_schema do
    field :uri, :string
    field :cid, :string
    field :author, :map
    field :reason, :string
    field :reason_subject, :string
    field :record, :map
    field :is_read, :boolean
    field :indexed_at, :utc_datetime
    field :labels, {:array, :map}
  end

  @doc """
  Creates a changeset for validating a notification.
  """
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [
      :uri,
      :cid,
      :author,
      :reason,
      :reason_subject,
      :record,
      :is_read,
      :indexed_at,
      :labels
    ])
    |> validate_required([
      :uri,
      :cid,
      :author,
      :reason,
      :record,
      :is_read,
      :indexed_at
    ])
    |> validate_format(:uri, ~r/^at:\/\//, message: "must be a valid AT-URI")
    |> validate_inclusion(:reason, @valid_reasons, message: "must be one of: #{Enum.join(@valid_reasons, ", ")}")
    |> validate_format(:reason_subject, ~r/^at:\/\//,
      message: "must be a valid AT-URI",
      allow_blank: true,
      allow_nil: true
    )
  end

  @doc """
  Creates a new notification with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new notification, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, notification} -> notification
      {:error, changeset} -> raise "Invalid notification: #{inspect(changeset.errors)}"
    end
  end
end
