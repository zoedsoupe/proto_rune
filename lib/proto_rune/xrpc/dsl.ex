defmodule ProtoRune.XRPC.DSL do
  @moduledoc """
  Macros defining XRPC queries and procedures as plain functions.

  The generated functions are thin wrappers around
  `ProtoRune.XRPC.query/5` and `ProtoRune.XRPC.procedure/5`: they encode
  the method name into a snake_case function and attach an optional Peri
  schema declared with `param/2`. All request plumbing (base URL
  resolution, auth headers, execution) lives in `ProtoRune.XRPC`.

  ## Example

      defmodule MyApp.Bsky do
        import ProtoRune.XRPC.DSL

        # public query: get_profile(params \\\\ %{})
        defquery "app.bsky.actor.getProfile" do
          param :actor, {:required, :string}
        end

        # authenticated procedure: mute(session, params \\\\ %{})
        defprocedure "app.bsky.graph.muteActor", authenticated: true do
          param :actor, {:required, :string}
        end

        # both arities: get_posts(params) and get_posts(session, params)
        defquery "app.bsky.feed.getPosts", authenticated: :optional do
          param :uris, {:required, {:list, :string}}
        end
      end

  ## Authentication modes

    * omitted or `authenticated: false` - public; the generated function
      takes only params.
    * `authenticated: true` - the generated function takes the session as
      its first argument.
    * `authenticated: :optional` - generates both `fun(params)` (public)
      and `fun(session, params)` (authenticated).
    * `refresh: true` (procedures only) - generates `fun(session)` which
      authenticates with the session's `refresh_jwt`, as required by
      `com.atproto.server.refreshSession`.
  """

  alias ProtoRune.XRPC

  @doc """
  Defines an XRPC query function for `method`.
  """
  defmacro defquery(method, opts \\ [], block \\ []) do
    define(:query, method, opts, block)
  end

  @doc """
  Defines an XRPC procedure function for `method`.
  """
  defmacro defprocedure(method, opts \\ [], block \\ []) do
    define(:procedure, method, opts, block)
  end

  @doc """
  Declares a parameter and its Peri type inside a `defquery`/`defprocedure` block.
  """
  defmacro param(key, type) do
    quote do
      @param {unquote(key), unquote(type)}
    end
  end

  defp define(kind, method, opts, block) do
    {method, fun} = encode_method_name(method)

    defs =
      cond do
        Keyword.get(opts, :refresh, false) ->
          refresh_clause(method, fun)

        Keyword.get(opts, :authenticated, false) == :optional ->
          optional_clauses(kind, method, fun)

        Keyword.get(opts, :authenticated, false) ->
          authed_clause(kind, method, fun)

        true ->
          public_clause(kind, method, fun)
      end

    quote do
      Module.register_attribute(__MODULE__, :param, accumulate: true)

      unquote(block)

      @proto_rune_schema (
                           params = @param
                           Module.delete_attribute(__MODULE__, :param)
                           if params == [], do: nil, else: Map.new(params)
                         )

      unquote(defs)
    end
  end

  defp authed_clause(kind, method, fun) do
    quote do
      def unquote(fun)(session, params \\ %{}, opts \\ []) do
        ProtoRune.XRPC.unquote(kind)(unquote(method), session, params, @proto_rune_schema, opts)
      end
    end
  end

  defp public_clause(kind, method, fun) do
    quote do
      def unquote(fun)(params \\ %{}, opts \\ []) do
        ProtoRune.XRPC.unquote(kind)(unquote(method), nil, params, @proto_rune_schema, opts)
      end
    end
  end

  # No default arguments here: `fun(session)` and `fun(params)` would be
  # indistinguishable at arity 1, so the session variant keeps both
  # arguments required. `opts` (forwarded to `ProtoRune.XRPC.query/5` and
  # `procedure/5`) only fits on the authenticated clause at arity 3; for an
  # anonymous call with options, pass `nil` as the session.
  defp optional_clauses(kind, method, fun) do
    quote do
      def unquote(fun)(session, params) do
        ProtoRune.XRPC.unquote(kind)(unquote(method), session, params, @proto_rune_schema)
      end

      def unquote(fun)(session, params, opts) do
        ProtoRune.XRPC.unquote(kind)(unquote(method), session, params, @proto_rune_schema, opts)
      end

      def unquote(fun)(params) do
        ProtoRune.XRPC.unquote(kind)(unquote(method), nil, params, @proto_rune_schema)
      end
    end
  end

  # `com.atproto.server.refreshSession` authenticates with the refresh
  # JWT instead of the access token, so it does not fit the session
  # behaviour pipeline.
  defp refresh_clause(method, fun) do
    quote do
      def unquote(fun)(%{refresh_jwt: refresh} = session, opts \\ []) do
        base_url = Map.get(session, :service_url)

        unquote(method)
        |> XRPC.Procedure.new(base_url: base_url)
        |> XRPC.Procedure.put_header(:authorization, "Bearer #{refresh}")
        |> XRPC.Client.execute(http: Keyword.get(opts, :http, []))
      end
    end
  end

  @doc false
  def encode_method_name(method) when is_binary(method) do
    {method,
     method
     |> String.split(".")
     |> List.last()
     |> ProtoRune.Case.snakelize()
     |> String.to_atom()}
  end
end
