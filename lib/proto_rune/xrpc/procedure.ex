defmodule ProtoRune.XRPC.Procedure do
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

  defstruct [:method, :body, :parser, :headers, :base_url]

  @doc """
  Creates a new procedure with the given method.

  ## Options

  - `:from` - Parser module for body validation
  - `:base_url` - Service base URL (e.g., "https://bsky.social")

  ## Examples

      Procedure.new("app.bsky.feed.post")
      Procedure.new("app.bsky.feed.post", from: parser, base_url: "https://bsky.social")
  """
  def new(method, opts \\ []) when is_binary(method) do
    %__MODULE__{
      method: method,
      parser: Keyword.get(opts, :from),
      body: %{},
      headers: %{},
      base_url: Keyword.get(opts, :base_url)
    }
  end

  def put_body(%__MODULE__{} = proc, body) do
    with {:ok, body} <- Peri.validate(proc.parser, body) do
      {:ok, %{proc | body: Map.new(body)}}
    end
  end

  def put_header(%__MODULE__{} = proc, key, value) do
    put_in(proc, [Access.key!(:headers), key], value)
  end

  @doc """
  Sets the base URL for the procedure.

  ## Examples

      proc = Procedure.new("app.bsky.feed.post")
      proc = Procedure.put_base_url(proc, "https://bsky.social")
  """
  def put_base_url(%__MODULE__{} = proc, base_url) when is_binary(base_url) do
    %{proc | base_url: base_url}
  end

  defimpl String.Chars, for: __MODULE__ do
    alias ProtoRune.XRPC.Config
    alias ProtoRune.XRPC.Procedure

    def to_string(%Procedure{} = proc) do
      # Use explicit base_url if provided, otherwise fall back to config
      base_url = proc.base_url || Config.get(:base_url) || "https://bsky.social/xrpc"
      Path.join(base_url, proc.method)
    end
  end
end
