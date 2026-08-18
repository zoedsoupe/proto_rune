defmodule ProtoRune.XRPC.Client do
  @moduledoc """
  The `XRPC.Client` module handles executing queries and procedures in the XRPC system. It interacts with external services through HTTP requests and performs response validation and schema parsing. The client supports both GET and POST requests, depending on whether the request is a query or a procedure.

  ## Overview

  This module allows:
  - **Executing Queries**: Executes `GET` requests for queries.
  - **Executing Procedures**: Executes `POST` requests for procedures with a body.
  - **Error Handling**: Maps various HTTP response codes to custom error messages.

  ## Functions

  ### `execute/1`

  Executes an XRPC query or procedure.

  - For **queries**, it performs a `GET` request and validates the query parameters.
  - For **procedures**, it performs a `POST` request and validates the request body.
  """

  alias ProtoRune.HTTPClient
  alias ProtoRune.XRPC.Error
  alias ProtoRune.XRPC.Procedure
  alias ProtoRune.XRPC.Query

  @doc """
  Executes an XRPC query or procedure.

  Dispatches to the appropriate HTTP method based on the type:
  - Query: GET request
  - Procedure: POST request

  ## Options

  - `:session` - A session implementing the `ProtoRune.Session`
    behaviour. When given, a 401 response demanding a fresh DPoP nonce
    (`use_dpop_nonce`) is retried once with the server-provided nonce.

  ## Examples

      # Execute a query
      query = Query.new("app.bsky.actor.getProfile")
      {:ok, response} = Client.execute(query)

      # Execute a procedure
      proc = Procedure.new("com.atproto.server.createSession")
      {:ok, response} = Client.execute(proc)
  """
  def execute(req, opts \\ [])

  def execute(%Query{} = query, opts) do
    session = Keyword.get(opts, :session)
    url = to_string(query)

    request = fn headers ->
      HTTPClient.request(:get, url, headers: format_headers(headers))
    end

    query.headers
    |> run_with_nonce_retry(request, session, "GET", url)
    |> parse_http(query.response)
  end

  def execute(%Procedure{raw_body: true} = proc, opts) do
    session = Keyword.get(opts, :session)
    url = to_string(proc)

    request = fn headers ->
      HTTPClient.request(:post, url, body: proc.body, headers: format_headers(headers))
    end

    proc.headers
    |> run_with_nonce_retry(request, session, "POST", url)
    |> parse_http(proc.response)
  end

  def execute(%Procedure{} = proc, opts) do
    session = Keyword.get(opts, :session)
    url = to_string(proc)
    body = ProtoRune.Case.camelize_enum(proc.body)

    request = fn headers ->
      HTTPClient.request(:post, url, json: body, headers: format_headers(headers))
    end

    proc.headers
    |> run_with_nonce_retry(request, session, "POST", url)
    |> parse_http(proc.response)
  end

  # Convert headers map to list of tuples for HTTPClient
  defp format_headers(headers) when is_map(headers) do
    Enum.map(headers, fn {k, v} -> {to_string(k), v} end)
  end

  # A 401 demanding a fresh DPoP nonce is retried once with the
  # server-provided nonce, mirroring the authorization-server retry in
  # ProtoRune.Atproto.OAuth. The updated session stays internal to the
  # call: nonces are not persisted.
  defp run_with_nonce_retry(headers, request, session, method, url) do
    case request.(headers) do
      {:ok, %{status: 401} = resp} = result ->
        case nonce_retry_headers(resp, headers, session, method, url) do
          {:ok, retry_headers} -> request.(retry_headers)
          :error -> result
        end

      other ->
        other
    end
  end

  defp nonce_retry_headers(_resp, _headers, nil, _method, _url), do: :error

  defp nonce_retry_headers(resp, headers, session, method, url) do
    with %{"error" => "use_dpop_nonce"} <- decode_error_body(resp.body),
         nonce when is_binary(nonce) <- get_header(Map.get(resp, :headers), "dpop-nonce"),
         {:ok, session} <- put_dpop_nonce(session, nonce),
         {:ok, auth_headers, _session} <- ProtoRune.Session.authorization_headers(session, method, url) do
      {:ok, Map.merge(headers, auth_headers)}
    else
      _other -> :error
    end
  end

  # Only OAuth sessions carry a DPoP nonce
  defp put_dpop_nonce(%ProtoRune.Atproto.OAuth.Session{} = session, nonce) do
    {:ok, %{session | dpop_nonce: nonce}}
  end

  defp put_dpop_nonce(_session, _nonce), do: :error

  defp decode_error_body(body) when is_map(body), do: body

  defp decode_error_body(body) when is_binary(body) do
    case JSON.decode(body) do
      {:ok, decoded} when is_map(decoded) -> decoded
      _other -> %{}
    end
  end

  defp decode_error_body(_body), do: %{}

  # Adapters deliver headers either as a list of tuples (test stubs) or
  # as a map of downcased names to value lists (Req)
  defp get_header(headers, name) when is_list(headers) do
    Enum.find_value(headers, fn {key, value} ->
      if String.downcase(to_string(key)) == name, do: value
    end)
  end

  defp get_header(headers, name) when is_map(headers) do
    Enum.find_value(headers, fn {key, value} ->
      if String.downcase(to_string(key)) == name, do: value |> List.wrap() |> List.first()
    end)
  end

  defp get_header(_headers, _name), do: nil

  defp parse_http({:error, err}, _response), do: {:error, err}

  defp parse_http({:ok, %{status: status} = resp}, _response) when status >= 400 do
    {:error, Error.from(%{resp | body: decode_body(resp.body)})}
  end

  defp parse_http({:ok, %{status: status} = resp}, response) when status in [200, 201] do
    decode_success(resp, response)
  end

  defp decode_success(resp, :binary) do
    {:ok, %{content_type: content_type(resp), body: resp.body}}
  end

  defp decode_success(resp, :json) do
    {:ok, resp.body |> decode_body() |> ProtoRune.Case.snakelize_enum()}
  end

  # :auto routes on the response content-type; a missing content-type
  # decodes as JSON
  defp decode_success(resp, :auto) do
    case content_type(resp) do
      nil -> decode_success(resp, :json)
      "application/json" -> decode_success(resp, :json)
      _other -> decode_success(resp, :binary)
    end
  end

  # Compares the media type only, dropping any "; charset=..." suffix
  defp content_type(resp) do
    case get_header(Map.get(resp, :headers), "content-type") do
      nil -> nil
      value -> value |> String.split(";", parts: 2) |> hd() |> String.trim() |> String.downcase()
    end
  end

  defp decode_body(body) when body in ["", nil], do: %{}
  defp decode_body(body) when is_binary(body), do: JSON.decode!(body)
  defp decode_body(body), do: body
end
