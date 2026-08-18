defmodule ProtoRune.Atproto.OAuth.SessionManagerTest do
  use ExUnit.Case, async: false

  alias ProtoRune.Atproto.OAuth.Client
  alias ProtoRune.Atproto.OAuth.Session
  alias ProtoRune.Atproto.OAuth.SessionManager
  alias ProtoRune.Security
  alias ProtoRune.Security.Crypto

  @issuer "https://auth.test"
  @token_url "https://auth.test/oauth/token"
  @revoke_url "https://auth.test/oauth/revoke"
  @did "did:plc:test123"

  @events [
    [:proto_rune, :oauth, :refresh, :start],
    [:proto_rune, :oauth, :refresh, :stop],
    [:proto_rune, :oauth, :refresh, :exception],
    [:proto_rune, :oauth, :revoke, :start],
    [:proto_rune, :oauth, :revoke, :stop],
    [:proto_rune, :oauth, :revoke, :exception]
  ]

  defmodule HTTPStub do
    @moduledoc false

    @behaviour ProtoRune.HTTPClient.Adapter

    @impl true
    def request(method, url, opts) do
      handler = Application.fetch_env!(:proto_rune, :http_stub_handler)
      handler.(method, url, opts)
    end
  end

  defmodule MemoryStore do
    @moduledoc false

    @behaviour ProtoRune.Security.TokenStore

    @impl true
    def put(id, blob, opts), do: Agent.update(opts[:pid], &Map.put(&1, id, blob))

    @impl true
    def fetch(id, opts) do
      case Agent.get(opts[:pid], &Map.fetch(&1, id)) do
        {:ok, blob} -> {:ok, blob}
        :error -> {:error, :not_found}
      end
    end

    @impl true
    def delete(id, opts), do: Agent.update(opts[:pid], &Map.delete(&1, id))
  end

  setup do
    for key <- [:http_client, :http_stub_handler, :retry, :rate_limit] do
      previous = Application.get_env(:proto_rune, key)
      on_exit(fn -> restore_env(key, previous) end)
    end

    Application.put_env(:proto_rune, :http_client, HTTPStub)
    Application.put_env(:proto_rune, :retry, false)
    Application.put_env(:proto_rune, :rate_limit, false)

    {:ok, store_pid} = Agent.start_link(fn -> %{} end)

    {:ok, client} =
      Client.new(
        client_id: "https://myapp.test/oauth/client-metadata.json",
        redirect_uri: "https://myapp.test/oauth/callback"
      )

    test_pid = self()
    handler_id = "oauth-session-manager-test-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      @events,
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    {:ok, client: client, store: {MemoryStore, [pid: store_pid]}, store_pid: store_pid}
  end

  test "refreshes on schedule, rotates tokens and persists through the store", %{
    client: client,
    store: store,
    store_pid: store_pid
  } do
    session = session(client, expires_at: System.system_time(:second) + 2)

    Application.put_env(:proto_rune, :http_stub_handler, fn :post, @token_url, opts ->
      form = opts[:form]

      assert form["grant_type"] == "refresh_token"
      assert form["refresh_token"] == "rt-1"
      assert form["client_id"] == client.client_id

      {:ok,
       %{
         status: 200,
         body: %{
           "access_token" => "at-2",
           "refresh_token" => "rt-2",
           "token_type" => "DPoP",
           "expires_in" => 3600,
           "sub" => @did
         },
         headers: [{"dpop-nonce", "nonce-9"}]
       }}
    end)

    {:ok, pid} =
      SessionManager.start_link(
        session: session,
        client: client,
        store: store,
        refresh_fraction: 0.1
      )

    assert_eventually(fn -> SessionManager.session(pid).access_token == "at-2" end)

    fresh = SessionManager.session(pid)
    assert fresh.refresh_token == "rt-2"
    assert fresh.dpop_nonce == "nonce-9"

    assert {:ok, blob} = MemoryStore.fetch(@did, pid: store_pid)
    assert %Session{access_token: "at-2", refresh_token: "rt-2"} = :erlang.binary_to_term(blob)

    assert_received {:telemetry, [:proto_rune, :oauth, :refresh, :start], _, %{did: @did}}
    assert_received {:telemetry, [:proto_rune, :oauth, :refresh, :stop], _, %{did: @did}}
  end

  test "encrypts the persisted session when a key is given", %{
    client: client,
    store: store,
    store_pid: store_pid
  } do
    key = Security.generate_key()
    session = session(client, expires_at: System.system_time(:second) + 2)

    Application.put_env(:proto_rune, :http_stub_handler, fn :post, @token_url, _opts ->
      {:ok,
       %{
         status: 200,
         body: %{"access_token" => "at-2", "refresh_token" => "rt-2", "sub" => @did},
         headers: []
       }}
    end)

    {:ok, pid} =
      SessionManager.start_link(
        session: session,
        client: client,
        store: store,
        key: key,
        refresh_fraction: 0.1
      )

    assert_eventually(fn -> SessionManager.session(pid).access_token == "at-2" end)

    assert {:ok, blob} = MemoryStore.fetch(@did, pid: store_pid)
    assert {:ok, plaintext} = Crypto.decrypt(blob, key)
    assert %Session{access_token: "at-2"} = :erlang.binary_to_term(plaintext)
  end

  test "stops with a descriptive reason when the refresh fails", %{client: client, store: store} do
    Process.flag(:trap_exit, true)

    session = session(client, expires_at: System.system_time(:second) + 2)

    Application.put_env(:proto_rune, :http_stub_handler, fn :post, @token_url, _opts ->
      {:ok, %{status: 400, body: %{"error" => "invalid_grant"}, headers: []}}
    end)

    {:ok, pid} =
      SessionManager.start_link(
        session: session,
        client: client,
        store: store,
        refresh_fraction: 0.1
      )

    assert_receive {:EXIT, ^pid, {:refresh_failed, {:oauth_error, 400, %{"error" => "invalid_grant"}}}},
                   2_000

    assert_received {:telemetry, [:proto_rune, :oauth, :refresh, :stop], _,
                     %{did: @did, error: {:oauth_error, 400, %{"error" => "invalid_grant"}}}}
  end

  test "logout revokes, deletes the stored session and stops", %{
    client: client,
    store: store,
    store_pid: store_pid
  } do
    session = session(client)
    test_pid = self()

    Application.put_env(:proto_rune, :http_stub_handler, fn
      :get, @issuer <> "/.well-known/oauth-authorization-server", _opts ->
        {:ok, %{status: 200, body: authorization_server_metadata(), headers: []}}

      :post, @revoke_url, opts ->
        form = opts[:form]

        assert form["token"] == "rt-1"
        assert form["client_id"] == client.client_id
        assert {"dpop", _proof} = List.keyfind(opts[:headers], "dpop", 0)

        send(test_pid, :revoked)

        {:ok, %{status: 200, body: "", headers: []}}
    end)

    :ok = MemoryStore.put(@did, :erlang.term_to_binary(session), pid: store_pid)

    {:ok, pid} = SessionManager.start_link(session: session, client: client, store: store)
    ref = Process.monitor(pid)

    assert :ok = SessionManager.logout(pid)
    assert_receive :revoked
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    assert {:error, :not_found} = MemoryStore.fetch(@did, pid: store_pid)

    assert_received {:telemetry, [:proto_rune, :oauth, :revoke, :start], _, %{did: @did}}
    assert_received {:telemetry, [:proto_rune, :oauth, :revoke, :stop], _, %{did: @did}}
  end

  test "registers under the session DID in a host-started Registry", %{client: client, store: store} do
    registry = :"oauth-registry-#{System.unique_integer([:positive])}"
    start_supervised!({Registry, keys: :unique, name: registry})

    {:ok, pid} =
      SessionManager.start_link(
        session: session(client),
        client: client,
        store: store,
        registry: registry
      )

    assert [{^pid, _value}] = Registry.lookup(registry, @did)

    via = {:via, Registry, {registry, @did}}
    assert %Session{did: @did} = SessionManager.session(via)
  end

  # Helpers

  defp restore_env(key, nil), do: Application.delete_env(:proto_rune, key)
  defp restore_env(key, value), do: Application.put_env(:proto_rune, key, value)

  defp session(client, opts \\ []) do
    %Session{
      did: @did,
      handle: "alice.test",
      access_token: "at-1",
      refresh_token: "rt-1",
      token_type: "DPoP",
      service_url: "https://pds.test",
      issuer: @issuer,
      token_endpoint: @token_url,
      dpop_key: client.dpop_key,
      dpop_jwk: client.dpop_jwk,
      expires_at: Keyword.get(opts, :expires_at)
    }
  end

  defp authorization_server_metadata do
    %{
      "issuer" => @issuer,
      "authorization_endpoint" => "https://auth.test/oauth/authorize",
      "token_endpoint" => @token_url,
      "pushed_authorization_request_endpoint" => "https://auth.test/oauth/par",
      "revocation_endpoint" => @revoke_url
    }
  end

  defp assert_eventually(fun, attempts \\ 40) do
    if fun.() do
      :ok
    else
      if attempts == 0 do
        flunk("condition not met in time")
      else
        Process.sleep(50)
        assert_eventually(fun, attempts - 1)
      end
    end
  end
end
