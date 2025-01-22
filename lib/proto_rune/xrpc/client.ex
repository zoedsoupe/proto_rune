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

  alias ProtoRune.XRPC.Case
  alias ProtoRune.XRPC.Procedure
  alias ProtoRune.XRPC.Query

  def execute(%Query{} = query) do
    query
    |> to_string()
    |> Req.get(headers: query.headers)
    |> parse_http()

    # |> parse_schema(query)
  end

  def execute(%Procedure{} = proc) do
    body = apply_case_map(proc.body, &Case.camelize/1)

    proc
    |> to_string()
    |> Req.post(json: body, decode_json: [keys: :strings])
    |> parse_http()

    # |> parse_schema(proc)
  end

  defp parse_http({:error, err}), do: {:error, err}
  defp parse_http({:ok, %{status: 401}}), do: {:error, :unauthorized}
  defp parse_http({:ok, %{status: 404}}), do: {:error, :not_found}
  defp parse_http({:ok, %{status: 403}}), do: {:error, :forbidden}
  defp parse_http({:ok, %{status: 413}}), do: {:error, :payload_too_large}
  defp parse_http({:ok, %{status: 501}}), do: {:error, :not_implemented}
  defp parse_http({:ok, %{status: 502}}), do: {:error, :bad_gateway}
  defp parse_http({:ok, %{status: 503}}), do: {:error, :service_unavailable}
  defp parse_http({:ok, %{status: 504}}), do: {:error, :gateway_timeout}

  defp parse_http({:ok, %{status: 429} = resp}) do
    retry_after = Req.Response.get_header(resp, "retry-after")
    {:error, {:rate_limited, retry_after}}
  end

  defp parse_http({:ok, %{status: 500, body: body}}), do: {:error, {:server_error, body}}

  defp parse_http({:ok, %{status: 400, body: error}}) do
    {:error, apply_case_map(error, &Case.snakelize/1)}
  end

  defp parse_http({:ok, %{status: status, body: body}}) when status in [200, 201] do
    {:ok, apply_case_map(body, &Case.snakelize/1)}
  end

  # defp parse_schema({:error, _err} = err, _), do: err
  # defp parse_schema({:ok, body}, %{schema: schema}), do: schema.parse(body)

  def apply_case_map(map, case_fun) when is_map(map) do
    Map.new(map, &apply_case_map_element(&1, case_fun))
  end

  def apply_case_map(elem, _fun), do: elem

  defp apply_case_map_element({k, v}, case) when is_map(v) do
    snake_key = case.(to_string(k))
    {String.to_atom(snake_key), apply_case_map(v, case)}
  end

  defp apply_case_map_element({k, v}, case) when is_list(v) do
    snake_key = case.(to_string(k))
    {String.to_atom(snake_key), Enum.map(v, &apply_case_map(&1, case))}
  end

  defp apply_case_map_element({k, v}, case) do
    snake_key = case.(to_string(k))
    {String.to_atom(snake_key), v}
  end
end
