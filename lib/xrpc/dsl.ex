defmodule XRPC.DSL do
  @moduledoc """
  The `XRPC.DSL` module provides macros to define queries and procedures for interacting with the XRPC system, simplifying the creation of API methods for querying or performing procedures. It supports building custom XRPC queries and procedures by encoding method names and dynamically generating functions based on user-defined parameters.

  ## Overview

  The primary purpose of this module is to offer a simple DSL for defining queries and procedures in Elixir projects using XRPC. It automates the generation of functions that initiate XRPC requests, reducing boilerplate code for developers.

  ### Key Features:
  - **Query Definition**: Use the `defquery/1` macro to define an XRPC query method.
  - **Procedure Definition**: Use the `defprocedure/2` macro to define an XRPC procedure method.
  - **Parameter Handling**: The `param/2` macro allows specifying parameters and their types for queries and procedures.
  - **Automatic Method Name Encoding**: Converts method names to function names by snakelizing the last segment of the method.

  ## Macros

  ### `defquery/1`

  Defines a query function based on the given method name.

  ```elixir
  defquery("app.bsky.actor.getProfile")
  ```

  This creates a function that returns a new query for the `app.bsky.actor.getProfile` method.

  ### `defquery/2`

  Defines a query with parameters.

  ```elixir
  defquery("app.bsky.feed.getFeed", do: block)
  ```

  Within the `block`, you can specify parameters using the `param/2` macro. The generated function will include these parameters in the query.

  ### `defprocedure/2`

  Defines a procedure with parameters.

  ```elixir
  defprocedure("app.bsky.actor.mute", do: block)
  ```

  Similar to `defquery/2`, you can specify parameters in the `block` using the `param/2` macro. This will generate a function that returns a new procedure with the given method and parameters.

  ### `param/2`

  Defines a parameter for queries or procedures.

  ```elixir
  param(:actor_id, :string)
  ```

  This specifies a parameter with a key of `actor_id` and a type of `:string`, which will be included in the final query or procedure.

  ## Usage Example

  ```elixir
  defmodule MyApp.Bsky do
    use XRPC.DSL

    defquery "app.bsky.actor.getProfile"

    defprocedure "app.bsky.actor.mute" do
      param :actor_id, :string
    end
  end
  ```

  In this example:
  - `get_profile/0` is generated as a function that creates a query for `app.bsky.actor.getProfile`.
  - `mute/0` is generated as a function that creates a procedure for `app.bsky.actor.mute` with the parameter `:actor_id` of type `:string`.
  """

  alias XRPC.Query
  alias XRPC.Procedure

  defmacro __using__(_opts) do
    quote do
      import XRPC.DSL

      Module.register_attribute(__MODULE__, :query, accumulate: true)
      Module.register_attribute(__MODULE__, :procedure, accumulate: true)
    end
  end

  defmacro defquery(method) do
    {method, fun} = encode_method_name(method)

    quote do
      def unquote(fun)() do
        Query.new(unquote(method))
      end
    end
  end

  defmacro defquery(method, do: block) do
    {method, fun} = encode_method_name(method)

    quote do
      Module.register_attribute(__MODULE__, :param, accumulate: true)

      unquote(block)

      def unquote(fun)() do
        Query.new(unquote(method), from: Map.new(@param))
      end

      Module.delete_attribute(__MODULE__, :param)
    end
  end

  defmacro defprocedure(method, do: block) do
    {method, fun} = encode_method_name(method)

    quote do
      Module.register_attribute(__MODULE__, :param, accumulate: true)

      unquote(block)

      def unquote(fun)() do
        Procedure.new(unquote(method), from: Map.new(@param))
      end

      Module.delete_attribute(__MODULE__, :param)
    end
  end

  defmacro param(key, type) do
    quote do
      @param {unquote(key), unquote(type)}
    end
  end

  def encode_method_name(method) when is_binary(method) do
    {method,
     method
     |> String.split(".")
     |> List.last()
     |> XRPC.Case.snakelize()
     |> String.to_atom()}
  end
end
