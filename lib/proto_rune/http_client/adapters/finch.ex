defmodule ProtoRune.HTTPClient.Adapters.Finch do
  @moduledoc """
  The `HTTPClient.Adapter` implementation backed by `Finch`, issuing requests
  through the named `ProtoRune.Finch` pool supervised by
  `ProtoRune.Application`.

  ## Option mapping

    * `:json` - encoded with the stdlib `JSON.encode!/1` and sent with
      `content-type: application/json`
    * `:form` - encoded with `URI.encode_query/1` and sent with
      `content-type: application/x-www-form-urlencoded`
    * `:body` - raw binary, sent as-is (set `content-type` in `:headers`)
    * `:headers` - list of `{name, value}` tuples, passed through
    * `:timeout` - mapped to Finch's `:receive_timeout` (the total time the
      request waits for a response). The connect timeout is a pool-level
      setting now, configured on the `ProtoRune.Finch` pool via
      `:conn_opts` (`Finch`), not per request.

  ## Responses and decompression

  The body is returned raw: the adapter does no JSON decoding or
  decompression (callers decode at the protocol layer). The adapter sends
  `accept-encoding: identity` so servers do not compress responses, since
  nothing below would uncompress them; a caller-provided `accept-encoding`
  header is honored instead.
  """

  @behaviour ProtoRune.HTTPClient.Adapter

  @pool_name ProtoRune.Finch

  @doc """
  The name of the Finch pool this adapter issues requests through.
  """
  def pool_name, do: @pool_name

  @impl true
  def request(method, url, opts) do
    {headers, opts} = Keyword.pop(opts, :headers, [])
    {timeout, opts} = Keyword.pop(opts, :timeout)

    {body, headers} = build_body(opts, headers)
    headers = headers |> set_accept_encoding() |> normalize()

    # `:timeout` is a receive deadline; the connect timeout is a pool-level
    # setting (see the moduledoc).
    finch_opts = if timeout, do: [receive_timeout: timeout], else: []

    method
    |> Finch.build(url, headers, body)
    |> Finch.request(@pool_name, finch_opts)
    |> case do
      {:ok, %Finch.Response{status: status, headers: headers, body: body}} ->
        {:ok, %{status: status, headers: headers, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # One body key at a time: `json:` and `form:` are encodings of `body`.
  defp build_body(opts, headers) do
    cond do
      json = Keyword.get(opts, :json) ->
        headers = put_header(headers, "content-type", "application/json")
        {JSON.encode!(json), headers}

      form = Keyword.get(opts, :form) ->
        headers = put_header(headers, "content-type", "application/x-www-form-urlencoded")
        {URI.encode_query(form), headers}

      body = Keyword.get(opts, :body) ->
        {body, headers}

      true ->
        {nil, headers}
    end
  end

  defp put_header(headers, name, value) do
    case List.keyfind(headers, name, 0) do
      {_existing, _v} -> headers
      nil -> headers ++ [{name, value}]
    end
  end

  # Finch (Mint) neither decompresses nor advertises compression, so ask for
  # identity explicitly rather than receive a body nothing will uncompress.
  defp set_accept_encoding(headers) do
    case List.keyfind(headers, "accept-encoding", 0) do
      {_existing, _v} -> headers
      nil -> [{"accept-encoding", "identity"} | headers]
    end
  end

  # Finch requires binary header names and values.
  defp normalize(headers) do
    Enum.map(headers, fn {name, value} -> {to_string(name), to_string(value)} end)
  end
end
