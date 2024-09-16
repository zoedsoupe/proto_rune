defmodule ProtoRune.Bot.Poller.State do
  @moduledoc false

  import Peri

  @type t :: %__MODULE__{
          name: atom,
          interval: integer,
          process_from: NaiveDateTime.t(),
          server_pid: pid,
          session: map,
          last_seen: NaiveDateTime.t() | nil,
          cursor: String.t() | nil,
          attempt: integer
        }

  defschema(:state_t, %{
    name: {:required, :atom},
    interval: {:required, :integer},
    process_from: {:required, :naive_datetime},
    last_seen: :date,
    cursor: :string,
    attempt: {:integer, {:default, 0}},
    server_pid: {:required, :pid},
    session: {:required, :map}
  })

  @enforce_keys [:name, :interval, :process_from, :server_pid, :session]
  defstruct [
    :name,
    :interval,
    :process_from,
    :last_seen,
    :cursor,
    :attempt,
    :server_pid,
    :session
  ]

  @spec new(Enumerable.t()) :: {:ok, t} | {:error, term}
  def new(params) do
    with {:ok, data} <- state_t(params) do
      {:ok, struct(__MODULE__, data)}
    end
  end
end
