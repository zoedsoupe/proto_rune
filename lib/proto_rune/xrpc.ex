defmodule ProtoRune.XRPC do
  @moduledoc """
  Runtime entry points for executing XRPC queries and procedures.

  The `ProtoRune.XRPC.DSL` macros generate thin wrappers around the two
  functions in this module, so cross-cutting behaviour (base URL
  resolution, auth header negotiation, DPoP nonce retries) lives in
  exactly one place.

  Both functions accept an optional session: any struct implementing the
  `ProtoRune.Session` behaviour. With a session the request is
  authenticated (and retried once on a DPoP nonce challenge); without one
  the request is anonymous.

  ## Options

    * `:base_url` - overrides the XRPC base URL. Resolution order:
      this option, then the session's `service_url`, then the
      `:base_url` application env, then `"https://bsky.social/xrpc"`.
    * `:http` - options forwarded to `ProtoRune.HTTPClient.request/3`
      (`:adapter`, `:retry`, `:rate_limit`, ...).
  """

  alias ProtoRune.Config
  alias ProtoRune.Session
  alias ProtoRune.XRPC.Client
  alias ProtoRune.XRPC.Procedure
  alias ProtoRune.XRPC.Query

  @doc """
  Executes a query (HTTP GET) against `method`.

  `params` is a map or keyword list of query parameters, validated
  against `schema` (a Peri schema) when one is given. Pass `nil` as
  `session` for an anonymous call.
  """
  @spec query(String.t(), Session.t() | nil, map() | keyword(), term(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def query(method, session, params, schema, opts \\ []) do
    base_url = base_url(session, opts)
    url = Path.join(base_url, method)

    query =
      case schema do
        nil -> Query.new(method, base_url: base_url)
        schema -> Query.new(method, from: schema, base_url: base_url)
      end

    with {:ok, query} <- add_params(query, params),
         {:ok, headers, session} <- authorization_headers(session, "GET", url) do
      Client.execute(%{query | headers: Map.merge(query.headers, headers)}, exec_opts(session, opts))
    end
  end

  @doc """
  Executes a procedure (HTTP POST) against `method`.

  `params` is the JSON body as a map or keyword list, validated against
  `schema` when one is given. Pass `nil` as `session` for an anonymous
  call.
  """
  @spec procedure(String.t(), Session.t() | nil, map() | keyword(), term(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def procedure(method, session, params, schema, opts \\ []) do
    base_url = base_url(session, opts)
    url = Path.join(base_url, method)

    proc =
      case schema do
        nil -> Procedure.new(method, base_url: base_url)
        schema -> Procedure.new(method, from: schema, base_url: base_url)
      end

    with {:ok, proc} <- put_body(proc, params),
         {:ok, headers, session} <- authorization_headers(session, "POST", url) do
      Client.execute(%{proc | headers: Map.merge(proc.headers, headers)}, exec_opts(session, opts))
    end
  end

  @doc false
  def base_url(session, opts \\ []) do
    Keyword.get(opts, :base_url) ||
      (session && Session.service_url(session)) ||
      Config.default_base_url()
  end

  defp add_params(%Query{parser: nil} = query, params), do: {:ok, %{query | params: Map.new(params)}}
  defp add_params(%Query{} = query, params), do: Query.add_params(query, params)

  defp put_body(%Procedure{parser: nil} = proc, params), do: {:ok, %{proc | body: Map.new(params)}}
  defp put_body(%Procedure{} = proc, params), do: Procedure.put_body(proc, params)

  defp authorization_headers(nil, _method, _url), do: {:ok, %{}, nil}

  defp authorization_headers(session, method, url) do
    Session.authorization_headers(session, method, url)
  end

  defp session_opt(nil), do: []
  defp session_opt(session), do: [session: session]

  defp exec_opts(session, opts), do: [{:http, Keyword.get(opts, :http, [])} | session_opt(session)]

  @doc """
  Lazily paginates a cursor-based endpoint into a stream of items.

  `fetch_fun` receives the params map (with the `:cursor` key managed by
  the stream) and returns `{:ok, response}` or `{:error, reason}`.
  `items_key` names the list inside the response (`:feed`, `:posts`,
  `:notifications`, ...).

  Items are emitted directly; a failed page emits `{:error, reason}` as
  the final element before the stream halts, so consumers should match on
  it at the end:

      session
      |> then(fn s -> &ProtoRune.Bsky.Feed.get_author_feed(s, &1) end)
      |> ProtoRune.XRPC.paginate(%{actor: "alice.bsky.social"}, :feed)
      |> Stream.take(200)
      |> Enum.to_list()
  """
  @spec paginate((map() -> {:ok, map()} | {:error, term()}), map(), atom()) :: Enumerable.t()
  def paginate(fetch_fun, params \\ %{}, items_key) do
    Stream.resource(
      fn -> Map.new(params) end,
      fn
        :halt -> {:halt, nil}
        params -> next_page(fetch_fun.(params), params, items_key)
      end,
      fn _acc -> :ok end
    )
  end

  defp next_page({:ok, page}, params, items_key) do
    items = Map.get(page, items_key) || []

    case {items, Map.get(page, :cursor)} do
      {[], _cursor} -> {:halt, params}
      {items, nil} -> {items, :halt}
      {items, cursor} -> {items, Map.put(params, :cursor, cursor)}
    end
  end

  defp next_page({:error, reason}, _params, _items_key) do
    {[{:error, reason}], :halt}
  end
end
