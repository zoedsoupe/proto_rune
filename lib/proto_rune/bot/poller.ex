defmodule ProtoRune.Bot.Poller do
  @moduledoc """
  A GenServer module that handles periodic polling of notifications for a bot, and dispatches
  these notifications to the appropriate handler functions within the bot.

  The `Poller` connects to the ATProto or Bluesky notification systems and periodically polls
  for new notifications, processes them, and dispatches them as events to the bot server. It
  handles various types of notifications including replies, mentions, likes, reposts, and follows.

  ## Features

  - Periodic polling of notifications based on a customizable interval.
  - Supports exponential backoff in case of rate limiting or errors.
  - Handles session refresh when required.
  - Dispatches notifications like replies, mentions, quotes, likes, reposts, and follows to the bot.
  - Extensible to handle other types of notifications and custom behavior.

  ## Options

  - `:name` (required) - The name of the GenServer instance.
  - `:interval` (required) - The polling interval in seconds for checking new notifications.
  - `:process_from` - Start polling from a specific date/time.
  - `:last_seen` - The last seen date of notifications.
  - `:cursor` - The cursor to fetch subsequent notifications from the API.
  - `:attempt` - Number of polling attempts, used for backoff.
  - `:server_pid` (required) - The server process that handles events from the poller.
  - `:session` (required) - The session information used to authenticate API requests.

  ## Functions

  - `start_link/1`: Starts the `Poller` process with the given options.
  - `poll_notifications/1`: Fetches the latest notifications from the service and handles them.
  - `handle_notifications/2`: Dispatches each notification to the appropriate event handler in the bot server.
  - `handle_rate_limited/2`: Handles the rate-limiting case by applying exponential backoff before the next poll.
  - `handle_error/2`: Sends error events to the bot server.
  - `dispatch_notification/2`: Dispatches different types of notifications (e.g., replies, quotes, mentions, likes, reposts, follows) to the bot server.

  ## Example

  You can start the poller like this:

  ```elixir
  ProtoRune.Bot.Poller.start_link([
    name: :my_bot_poller,
    interval: 30,
    session: my_session,
    server_pid: self()
  ])
  ```

  The poller will then periodically fetch notifications and dispatch them to the bot server based on the event type.

  ## Backoff Strategy

  The poller implements an exponential backoff strategy when rate-limited or in case of errors.
  The backoff starts with the defined `interval` and increases exponentially with each failed attempt,
  up to a maximum of 5 minutes.

  ## Internal State

  The `State` struct is used to keep track of:
  - `name`: The name of the poller process.
  - `interval`: The polling interval in seconds.
  - `last_seen`: The last notification timestamp.
  - `cursor`: API cursor for fetching new notifications.
  - `attempt`: The number of failed attempts.
  - `session`: The current session for API requests.
  - `server_pid`: The PID of the server handling the notifications.
  """

  use GenServer

  alias ProtoRune.Atproto
  alias ProtoRune.Bot.Poller.State
  alias ProtoRune.Bsky

  require Logger

  @type option ::
          {:name, atom}
          | {:interval, integer}
          | {:process_from, NaiveDateTime.t()}
          | {:last_seen, Date.t()}
          | {:cursor, String.t()}
          | {:attempt, integer}
          | {:server_pid, pid}
          | {:session, map}
  @type kwargs :: nonempty_list(option)

  @spec start_link(kwargs) :: GenServer.on_start()
  def start_link(opts) do
    name = Access.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    {:ok, state} = State.new(opts)
    {:ok, state, {:continue, :poll}}
  end

  @impl true
  def handle_continue(:poll, %State{} = state) do
    schedule_polling(state)
    {:ok, state} = poll_notifications(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:poll, %State{} = state) do
    schedule_polling(state)
    {:ok, state} = poll_notifications(state)
    {:noreply, state}
  end

  def handle_info({:refresh_session, session}, %State{} = state) do
    {:noreply, %{state | session: session}}
  end

  @impl true
  def format_status({:state, state}) do
    {:state, Map.take(state, [:name, :interval, :process_from, :last_seen, :cursor, :attempt])}
  end

  def format_status(key), do: key

  @spec poll_notifications(State.t()) :: {:ok, State.t()}
  defp poll_notifications(%State{} = state) do
    case Bsky.Notification.list_notifications(state.session) do
      {:ok, data} -> handle_notifications(state, data)
      {:error, {:rate_limited, retry_after}} -> handle_rate_limited(state, retry_after)
      {:error, reason} -> handle_error(state, reason)
    end
  end

  defp handle_notifications(state, %{notifications: []}), do: {:noreply, state}

  defp handle_notifications(%State{} = state, data) do
    indexed_at = List.first(data[:notifications])[:indexed_at]
    {:ok, indexed_at} = NaiveDateTime.from_iso8601(indexed_at)
    last_seen = state.last_seen || indexed_at

    Task.start(fn ->
      for notification <- data[:notifications],
          NaiveDateTime.compare(indexed_at, last_seen) == :gt do
        dispatch_notification(state, notification)
      end
    end)

    {:ok, %{state | last_seen: indexed_at, cursor: data[:cursor]}}
  end

  defp handle_rate_limited(%State{} = state, retry_after) do
    interval = retry_after || backoff(state)
    Process.send_after(self(), :poll, interval)
    {:ok, %{state | attempt: state.attempt + 1}}
  end

  defp handle_error(%State{server_pid: pid} = state, reason) do
    send(pid, {:handle_event, :error, %{reason: reason}})
    {:ok, state}
  end

  defp dispatch_notification(%State{} = state, %{reason: "reply", uri: uri}) do
    # TODO ignore replies that aren't to the bot
    case Bsky.Feed.get_post_thread(state.session, uri: uri) do
      {:ok, data} -> send(state.server_pid, {:handle_event, :reply, data})
      {:error, reason} -> send(state.server_pid, {:handle_event, :error, reason})
    end
  end

  defp dispatch_notification(%State{} = state, %{reason: "quote", uri: uri}) do
    case Bsky.Feed.get_post_thread(state.session, uri: uri) do
      {:ok, data} -> send(state.server_pid, {:handle_event, :quote, data})
      {:error, reason} -> send(state.server_pid, {:handle_event, :error, reason})
    end
  end

  defp dispatch_notification(%State{} = state, %{reason: "mention", uri: uri}) do
    case Bsky.Feed.get_post_thread(state.session, uri: uri) do
      {:ok, data} -> send(state.server_pid, {:handle_event, :mention, data})
      {:error, reason} -> send(state.server_pid, {:handle_event, :error, reason})
    end
  end

  defp dispatch_notification(%State{} = state, %{reason: "repost"} = notf) do
    case Bsky.Feed.get_post_thread(state.session, uri: notf.reason_subject) do
      {:ok, data} ->
        send(
          state.server_pid,
          {:handle_event, :repost, %{user: notf.author, post: data, uri: notf.uri}}
        )

      {:error, reason} ->
        send(state.server_pid, {:handle_event, :error, reason})
    end
  end

  defp dispatch_notification(
         %State{} = state,
         %{reason: "like", reason_subject: reason_subject} = notf
       ) do
    {:ok, subject} = Atproto.parse_at_uri(reason_subject)

    if match?({_, :post}, subject) do
      case Bsky.Feed.get_post_thread(state.session, uri: reason_subject) do
        {:ok, data} ->
          send(
            state.server_pid,
            {:handle_event, :like, %{uri: notf.uri, user: notf.author, subject: data}}
          )

        {:error, reason} ->
          send(state.server_pid, {:handle_event, :error, reason})
      end
    end
  end

  defp dispatch_notification(%State{} = state, %{reason: "follow"} = notf) do
    send(state.server_pid, {:handle_event, :follow, %{user: notf.author, uri: notf.uri}})
  end

  defp dispatch_notification(_state, %{reason: reason}) do
    Logger.warning("[#{__MODULE__}] ==> Unhandled notification reason: #{inspect(reason)}")
  end

  @max_backoff :timer.minutes(5)

  # implement exponential backoff
  defp backoff(%State{interval: interval, attempt: attempt}) do
    min(@max_backoff, :timer.seconds(interval) ** attempt)
  end

  defp schedule_polling(%State{interval: interval}) do
    Process.send_after(self(), :poll, :timer.seconds(interval))
  end
end
