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

  alias ProtoRune.XRPC.Error
  alias ProtoRune.XRPC.Procedure
  alias ProtoRune.XRPC.Query

  def execute(%Query{} = query) do
    query
    |> to_string()
    |> Req.get(headers: query.headers)
    |> parse_http()
  end

  def execute(%Procedure{} = proc) do
    body = ProtoRune.Case.camelize_enum(proc.body)

    proc
    |> to_string()
    |> Req.post(json: body, decode_json: [keys: :strings])
    |> parse_http()
  end

  defp parse_http({:error, err}), do: {:error, err}

  defp parse_http({:ok, %{status: status} = resp}) when status >= 400 do
    {:error, Error.from(resp)}
  end

  defp parse_http({:ok, %{status: status, body: body}}) when status in [200, 201] do
    {:ok, ProtoRune.Case.snakelize_enum(body)}
  end
end
