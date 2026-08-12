defmodule ProtoRune.Bot.Firehose.State do
  @moduledoc false

  import Peri

  @type t :: %__MODULE__{
          name: atom,
          relay: String.t(),
          cursor: non_neg_integer | nil,
          auto_reconnect: boolean,
          backoff_initial: pos_integer,
          backoff_max: pos_integer,
          transport: module,
          transport_opts: keyword,
          server_pid: pid,
          firehose: pid | nil
        }

  defschema(:state_t, %{
    name: {:required, :atom},
    relay: {:string, {:default, "wss://bsky.network"}},
    cursor: {{:either, {:string, :integer}}, {:default, "latest"}},
    auto_reconnect: {:boolean, {:default, true}},
    backoff_initial: {:integer, {:default, 1_000}},
    backoff_max: {:integer, {:default, 30_000}},
    transport: {:atom, {:default, ProtoRune.Firehose.Transport.Gun}},
    transport_opts: {:any, {:default, []}},
    server_pid: {:required, :pid}
  })

  @enforce_keys [:name, :server_pid]
  defstruct [
    :name,
    :relay,
    :cursor,
    :auto_reconnect,
    :backoff_initial,
    :backoff_max,
    :transport,
    :transport_opts,
    :server_pid,
    :firehose
  ]

  @spec new(Enumerable.t()) :: {:ok, t} | {:error, term}
  def new(params) do
    with {:ok, data} <- state_t(params),
         {:ok, data} <- normalize_cursor(data) do
      {:ok, struct(__MODULE__, data)}
    end
  end

  defp normalize_cursor(%{cursor: cursor} = data) when cursor in [nil, "latest"] do
    {:ok, %{data | cursor: nil}}
  end

  defp normalize_cursor(%{cursor: cursor} = data) when is_binary(cursor) do
    case Integer.parse(cursor) do
      {seq, ""} when seq >= 0 -> {:ok, %{data | cursor: seq}}
      _invalid -> {:error, :invalid_cursor}
    end
  end

  defp normalize_cursor(%{cursor: cursor} = data) when is_integer(cursor) and cursor >= 0 do
    {:ok, data}
  end

  defp normalize_cursor(_data), do: {:error, :invalid_cursor}
end
