defmodule ProtoRune.XRPC.DSL do
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
    import XRPC.DSL

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

  alias ProtoRune.Session
  alias ProtoRune.XRPC.Client
  alias ProtoRune.XRPC.Config
  alias ProtoRune.XRPC.Procedure
  alias ProtoRune.XRPC.Query

  @type options :: [
          for: atom | nil,
          authenticated: boolean | :optional | nil,
          refresh: boolean | nil
        ]

  @spec defquery(String.t(), options) :: Macro.t()
  defmacro defquery(method, opts) do
    {method, fun} = encode_method_name(method)

    case Keyword.get(opts, :authenticated, false) do
      true -> authed_query(method, fun)
      :optional -> optional_query(method, fun)
      _other -> public_query(method, fun)
    end
  end

  @spec defquery(String.t(), options, do: Macro.t()) :: Macro.t()
  defmacro defquery(method, opts, do: block) do
    {method, fun} = encode_method_name(method)
    clauses = query_clauses(Keyword.get(opts, :authenticated, false), method, fun)

    quote do
      Module.register_attribute(__MODULE__, :param, accumulate: true)

      unquote(block)

      unquote(clauses)

      Module.delete_attribute(__MODULE__, :param)
    end
  end

  defp authed_query(method, fun) do
    quote do
      def unquote(fun)(session) do
        base_url = Session.service_url(session) || Config.default_base_url()
        url = Path.join(base_url, unquote(method))

        with {:ok, headers, session} <- Session.authorization_headers(session, "GET", url) do
          unquote(method)
          |> Query.new(base_url: base_url)
          |> then(&%{&1 | headers: Map.merge(&1.headers, headers)})
          |> Client.execute(session: session)
        end
      end
    end
  end

  defp optional_query(method, fun) do
    quote do
      unquote(authed_query(method, fun))
      unquote(public_query(method, fun))
    end
  end

  defp public_query(method, fun) do
    quote do
      def unquote(fun)() do
        unquote(method)
        |> Query.new()
        |> Client.execute()
      end
    end
  end

  defp query_clauses(true, method, fun), do: authed_query_with_params(method, fun)

  defp query_clauses(:optional, method, fun) do
    quote do
      unquote(authed_query_with_params(method, fun))
      unquote(public_query_with_params(method, fun))
    end
  end

  defp query_clauses(_other, method, fun), do: public_query_with_params(method, fun)

  defp authed_query_with_params(method, fun) do
    quote do
      def unquote(fun)(session, params) do
        base_url = Session.service_url(session) || Config.default_base_url()
        url = Path.join(base_url, unquote(method))
        query = Query.new(unquote(method), from: Map.new(@param), base_url: base_url)

        with {:ok, query} <- Query.add_params(query, params),
             {:ok, headers, session} <- Session.authorization_headers(session, "GET", url) do
          Client.execute(%{query | headers: Map.merge(query.headers, headers)}, session: session)
        end
      end
    end
  end

  defp public_query_with_params(method, fun) do
    quote do
      def unquote(fun)(params) do
        query = Query.new(unquote(method), from: Map.new(@param))

        with {:ok, query} <- Query.add_params(query, params) do
          Client.execute(query)
        end
      end
    end
  end

  @spec defprocedure(String.t(), options) :: Macro.t()
  defmacro defprocedure(method, opts) do
    authenticated = Keyword.get(opts, :authenticated, false)
    refresh = Keyword.get(opts, :refresh, false)
    {method, fun} = encode_method_name(method)

    quote do
      cond do
        unquote(authenticated) ->
          def unquote(fun)(session, params) do
            base_url = Session.service_url(session) || Config.default_base_url()
            url = Path.join(base_url, unquote(method))
            proc = Procedure.new(unquote(method), base_url: base_url)

            with {:ok, proc} <- Procedure.put_body(proc, params),
                 {:ok, headers, session} <- Session.authorization_headers(session, "POST", url) do
              Client.execute(%{proc | headers: Map.merge(proc.headers, headers)}, session: session)
            end
          end

        unquote(refresh) ->
          def unquote(fun)(%{refresh_jwt: refresh} = session) do
            # Extract service_url from session if present
            base_url = Map.get(session, :service_url)
            proc = Procedure.new(unquote(method), base_url: base_url)

            proc
            |> Procedure.put_header(:authorization, "Bearer #{refresh}")
            |> Client.execute()
          end

        true ->
          def unquote(fun)(params) do
            proc = Procedure.new(unquote(method))

            with {:ok, proc} <- Procedure.put_body(proc, params) do
              Client.execute(proc)
            end
          end
      end
    end
  end

  @spec defprocedure(String.t(), options, do: Macro.t()) :: Macro.t()
  defmacro defprocedure(method, opts, do: block) do
    authenticated = Keyword.get(opts, :authenticated, false)
    {method, fun} = encode_method_name(method)

    quote do
      Module.register_attribute(__MODULE__, :param, accumulate: true)

      unquote(block)

      if unquote(authenticated) do
        def unquote(fun)(session, params) do
          base_url = Session.service_url(session) || Config.default_base_url()
          url = Path.join(base_url, unquote(method))
          proc = Procedure.new(unquote(method), from: Map.new(@param), base_url: base_url)

          with {:ok, proc} <- Procedure.put_body(proc, params),
               {:ok, headers, session} <- Session.authorization_headers(session, "POST", url) do
            Client.execute(%{proc | headers: Map.merge(proc.headers, headers)}, session: session)
          end
        end
      else
        def unquote(fun)(params) do
          proc = Procedure.new(unquote(method), from: Map.new(@param))

          with {:ok, proc} <- Procedure.put_body(proc, params) do
            Client.execute(proc)
          end
        end
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
     |> ProtoRune.Case.snakelize()
     |> String.to_atom()}
  end
end
