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

  ## Examples

      # Execute a query
      query = Query.new("app.bsky.actor.getProfile")
      {:ok, response} = Client.execute(query)

      # Execute a procedure
      proc = Procedure.new("com.atproto.server.createSession")
      {:ok, response} = Client.execute(proc)
  """
  def execute(%Query{} = query) do
    url = to_string(query)
    headers = format_headers(query.headers)

    :get
    |> HTTPClient.request(url, headers: headers)
    |> parse_http(query.response)
  end

  def execute(%Procedure{raw_body: true} = proc) do
    url = to_string(proc)
    headers = format_headers(proc.headers)

    :post
    |> HTTPClient.request(url, body: proc.body, headers: headers)
    |> parse_http(proc.response)
  end

  def execute(%Procedure{} = proc) do
    url = to_string(proc)
    body = ProtoRune.Case.camelize_enum(proc.body)
    headers = format_headers(proc.headers)

    :post
    |> HTTPClient.request(url, json: body, headers: headers)
    |> parse_http(proc.response)
  end

  # Convert headers map to list of tuples for HTTPClient
  defp format_headers(headers) when is_map(headers) do
    Enum.map(headers, fn {k, v} -> {to_string(k), v} end)
  end

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
  defp content_type(%{headers: headers}) when is_list(headers) do
    Enum.find_value(headers, fn {key, value} ->
      if String.downcase(to_string(key)) == "content-type" do
        value |> String.split(";", parts: 2) |> hd() |> String.trim() |> String.downcase()
      end
    end)
  end

  defp content_type(_resp), do: nil

  defp decode_body(body) when body in ["", nil], do: %{}
  defp decode_body(body) when is_binary(body), do: JSON.decode!(body)
  defp decode_body(body), do: body
end
