defmodule XRPC.Query do
  @moduledoc """
  The `XRPC.Query` module is responsible for defining and managing queries in the XRPC system. It encapsulates the method, parameters, headers, and an optional parser, providing functions to create and manipulate query structures.

  ## Overview

  This module allows for:
  - **Creating Queries**: Use `new/1` or `new/2` to create a query with an optional parser.
  - **Adding Parameters and Headers**: Use `put_param/3` and `put_header/3` to add query parameters and headers.
  - **String Representation**: Converts a query to a string URL, including parameters if present.

  ## Functions

  ### `new/1`

  Creates a new query with the given method.

  ```elixir
  XRPC.Query.new("app.bsky.actor.getProfile")
  ```

  ### `new/2`

  Creates a new query with a method and a parser for validation.

  ```elixir
  XRPC.Query.new("app.bsky.feed.getFeed", from: MyParser)
  ```

  ### `put_param/3`

  Adds or updates a query parameter.

  ```elixir
  query = XRPC.Query.put_param(query, :actor_id, "123")
  ```

  ### `put_header/3`

  Adds or updates a request header.

  ```elixir
  query = XRPC.Query.put_header(query, "Authorization", "Bearer token")
  ```
  """

  defstruct [:method, :params, :parser, :headers]

  def new(method) when is_binary(method) do
    %__MODULE__{method: method, params: %{}, headers: %{}}
  end

  def new(method, from: parser) when is_binary(method) do
    %__MODULE__{
      method: method,
      parser: parser,
      params: %{},
      headers: %{}
    }
  end

  def put_param(%__MODULE__{} = query, key, value) do
    put_in(query, [Access.key!(:params), key], value)
  end

  def put_header(%__MODULE__{} = query, key, value) do
    put_in(query, [Access.key!(:headers), key], value)
  end

  defimpl String.Chars, for: __MODULE__ do
    alias XRPC.Query

    def to_string(%Query{} = query) do
      base = Path.join(XRPC.Config.get(:base_url), query.method)

      if Enum.empty?(query.params) do
        base
      else
        Enum.join([base, "?", URI.encode_query(query.params)])
      end
    end
  end
end
