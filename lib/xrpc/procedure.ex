defmodule XRPC.Procedure do
  @moduledoc """
  The `XRPC.Procedure` module represents a procedure in the XRPC system, encapsulating the method name, request body, and a parser for validating the body. It provides functions to create and manipulate procedure structures.

  ## Overview

  This module allows for:
  - **Creating Procedures**: Use the `new/2` function to create a new procedure with a method and a parser.
  - **Adding a Body**: Use the `put_body/2` function to attach a validated body to the procedure.
  - **String Representation**: The procedure can be converted to a string that represents its full URL.

  ## Functions

  ### `new/2`

  Creates a new procedure with a given method and parser.

  ```elixir
  XRPC.Procedure.new("app.bsky.actor.mute", from: MyParser)
  ```

  ### `put_body/2`

  Attaches a validated body to the procedure.

  ```elixir
  {:ok, updated_proc} = XRPC.Procedure.put_body(proc, %{"actor_id" => "123"})
  ```

  Validates the body using the specified parser and updates the procedure via [peri](https://hexdocs.pm/peri).
  """

  defstruct [:method, :body, :parser, :headers]

  def new(method, from: parser) when is_binary(method) do
    %__MODULE__{method: method, parser: parser, body: %{}, headers: %{}}
  end

  def put_body(%__MODULE__{} = proc, body) do
    with {:ok, body} <- Peri.validate(proc.parser, body) do
      {:ok, %{proc | body: Map.new(body)}}
    end
  end

  def put_header(%__MODULE__{} = proc, key, value) do
    put_in(proc, [Access.key!(:headers), key], value)
  end

  defimpl String.Chars, for: __MODULE__ do
    alias XRPC.Procedure

    def to_string(%Procedure{} = proc) do
      Path.join(XRPC.Config.get(:base_url), proc.method)
    end
  end
end
