defmodule ProtoRune.Bot.Jetstream.State do
  @moduledoc false

  import Peri

  @type t :: %__MODULE__{
          name: atom,
          relay: String.t(),
          wanted_collections: [String.t()],
          wanted_dids: [String.t()],
          cursor: non_neg_integer | nil,
          auto_reconnect: boolean,
          backoff_initial: pos_integer,
          backoff_max: pos_integer,
          transport: module,
          transport_opts: keyword,
          server_pid: pid,
          jetstream: pid | nil
        }

  defschema(:state_t, %{
    name: {:required, :atom},
    relay: {:string, {:default, "wss://jetstream2.us-east.bsky.network"}},
    wanted_collections: {{:list, :string}, {:default, []}},
    wanted_dids: {{:list, :string}, {:default, []}},
    cursor: :integer,
    auto_reconnect: {:boolean, {:default, true}},
    backoff_initial: {:integer, {:default, 1_000}},
    backoff_max: {:integer, {:default, 30_000}},
    transport: {:atom, {:default, ProtoRune.Firehose.Transport.Mint}},
    transport_opts: {:any, {:default, []}},
    server_pid: {:required, :pid}
  })

  @enforce_keys [:name, :server_pid]
  defstruct [
    :name,
    :relay,
    :wanted_collections,
    :wanted_dids,
    :cursor,
    :auto_reconnect,
    :backoff_initial,
    :backoff_max,
    :transport,
    :transport_opts,
    :server_pid,
    :jetstream
  ]

  @spec new(Enumerable.t()) :: {:ok, t} | {:error, term}
  def new(params) do
    with {:ok, data} <- state_t(params) do
      {:ok, struct(__MODULE__, data)}
    end
  end
end
