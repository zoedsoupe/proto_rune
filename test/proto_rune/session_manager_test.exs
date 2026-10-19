defmodule ProtoRune.SessionManagerTest do
  use ProtoRune.TestCase, async: true

  alias ProtoRune.Atproto.OAuth.Client
  alias ProtoRune.Atproto.OAuth.Session, as: OAuthSession
  alias ProtoRune.Atproto.Session
  alias ProtoRune.Security
  alias ProtoRune.Security.Crypto
  alias ProtoRune.Security.TokenStore
  alias ProtoRune.SessionManager

  @issuer "https://auth.test"
  @token_url "https://auth.test/oauth/token"
  @revoke_url "https://auth.test/oauth/revoke"
  @did "did:plc:test123"
  @exp 4_000_000_000

  @refresh_events [
    [:proto_rune, :session, :refresh, :start],
    [:proto_rune, :session, :refresh, :stop],
    [:proto_rune, :session, :refresh, :exception]
  ]

  @revoke_events [
    [:proto_rune, :session, :revoke, :start],
    [:proto_rune, :session, :revoke, :stop],
    [:proto_rune, :session, :revoke, :exception]
  ]

  defmodule MemoryStore do
    @moduledoc false

    @behaviour TokenStore

    def start_link, do: Agent.start_link(fn -> %{} end)

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

  # Fails the first N `put/3` calls, then behaves like a memory store.
  defmodule FlakyStore do
    @moduledoc false

    @behaviour TokenStore

    def start_link(failures), do: Agent.start_link(fn -> {failures, %{}} end)

    @impl true
    def put(id, blob, opts) do
      Agent.get_and_update(opts[:pid], fn {failures, map} ->
        if failures > 0 do
          {{:error, :storage_down}, {failures - 1, map}}
        else
          {:ok, {failures, Map.put(map, id, blob)}}
        end
      end)
    end

    @impl true
    def fetch(id, opts) do
      case Agent.get(opts[:pid], fn {_failures, map} -> Map.fetch(map, id) end) do
        {:ok, blob} -> {:ok, blob}
        :error -> {:error, :not_found}
      end
    end

    @impl true
    def delete(id, opts) do
      Agent.update(opts[:pid], fn {failures, map} -> {failures, Map.delete(map, id)} end)
    end
  end

  setup do
    {:ok, store_pid} = MemoryStore.start_link()
    test_pid = self()
    handler_id = "session-manager-test-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      @refresh_events ++ @revoke_events,
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    {:ok, store: {MemoryStore, [pid: store_pid]}, store_pid: store_pid, key: Security.generate_key()}
  end

  describe "Session.parse/1" do
    test "extracts expires_at from the access JWT exp claim" do
      {:ok, session} =
        Session.parse(%{
          access_jwt: jwt(@exp),
          refresh_jwt: "refresh",
          did: "did:plc:test",
          handle: "alice.test"
        })

      assert session.expires_at == @exp
    end

    test "yields nil expires_at for a malformed token" do
      {:ok, session} =
        Session.parse(%{
          access_jwt: "not-a-jwt",
          refresh_jwt: "refresh",
          did: "did:plc:test",
          handle: "alice.test"
        })

      assert session.expires_at == nil
    end
  end

  describe "SessionManager" do
    test "refreshes the session through the session behaviour" do
      test_pid = self()

      http =
        fake_http(fn :post, url, _opts ->
          send(test_pid, {:refresh_request, url})

          {:ok,
           %{
             status: 200,
             body:
               JSON.encode!(%{
                 "accessJwt" => jwt(@exp),
                 "refreshJwt" => "new-refresh",
                 "did" => "did:plc:test",
                 "handle" => "alice.test"
               })
           }}
        end)

      session = %Session{
        access_jwt: jwt(@exp),
        refresh_jwt: "old-refresh",
        did: "did:plc:test",
        handle: "alice.test",
        service_url: "https://pds.test/xrpc"
      }

      {:ok, pid} = SessionManager.start_link(session: session, refresh_opts: [http: http], refresh_fraction: 0.0)

      assert_receive {:refresh_request, url}, 1_000
      assert url =~ "com.atproto.server.refreshSession"
      assert %Session{refresh_jwt: "new-refresh"} = SessionManager.session(pid)
    end

    test "stops with refresh_failed when the refresh errors" do
      Process.flag(:trap_exit, true)

      http =
        fake_http(fn :post, _url, _opts ->
          {:ok, %{status: 500, body: "{}"}}
        end)

      session = %Session{
        access_jwt: jwt(@exp),
        refresh_jwt: "old-refresh",
        did: "did:plc:test",
        handle: "alice.test",
        service_url: "https://pds.test/xrpc"
      }

      {:ok, pid} = SessionManager.start_link(session: session, refresh_opts: [http: http], refresh_fraction: 0.0)
      ref = Process.monitor(pid)

      assert_receive {:DOWN, ^ref, :process, ^pid, {:refresh_failed, _reason}}, 1_000
    end

    test "raises a descriptive error when only one of :store and :key is given" do
      Process.flag(:trap_exit, true)

      session = %Session{
        access_jwt: jwt(@exp),
        refresh_jwt: "old-refresh",
        did: "did:plc:test",
        handle: "alice.test"
      }

      assert {:error, {%ArgumentError{message: ":store and :key must be given together"}, _stacktrace}} =
               SessionManager.start_link(session: session, store: {MemoryStore, [pid: self()]})
    end
  end

  describe "persistence across restarts" do
    test "restores the persisted session when it is newer than the boot-time one", %{
      store: store,
      store_pid: store_pid,
      key: key
    } do
      stored = app_password_session(refresh_jwt: "stored-refresh", expires_at: System.system_time(:second) + 60)
      boot = app_password_session(refresh_jwt: "boot-refresh", expires_at: System.system_time(:second) + 30)

      :ok = Security.save_session(stored, key, store)

      {:ok, pid} = SessionManager.start_link(session: boot, store: store, key: key)

      assert %Session{refresh_jwt: "stored-refresh"} = SessionManager.session(pid)
      assert @did |> MemoryStore.fetch(pid: store_pid) |> elem(0) == :ok
    end

    test "keeps the boot-time session when it is newer than the persisted one", %{
      store: store,
      key: key
    } do
      stored = app_password_session(refresh_jwt: "stored-refresh", expires_at: System.system_time(:second) + 30)
      boot = app_password_session(refresh_jwt: "boot-refresh", expires_at: System.system_time(:second) + 60)

      :ok = Security.save_session(stored, key, store)

      {:ok, pid} = SessionManager.start_link(session: boot, store: store, key: key)

      assert %Session{refresh_jwt: "boot-refresh"} = SessionManager.session(pid)
    end

    test "falls back to the boot-time session when the store is empty", %{store: store, key: key} do
      boot = app_password_session(refresh_jwt: "boot-refresh")

      {:ok, pid} = SessionManager.start_link(session: boot, store: store, key: key)

      assert %Session{refresh_jwt: "boot-refresh"} = SessionManager.session(pid)
    end

    test "falls back to the boot-time session when the stored one cannot be decrypted", %{
      store: store,
      store_pid: store_pid,
      key: key
    } do
      wrong_key = Security.generate_key()
      boot = app_password_session(refresh_jwt: "boot-refresh")

      :ok = Security.save_session(app_password_session(refresh_jwt: "stored-refresh"), wrong_key, store)

      {:ok, pid} = SessionManager.start_link(session: boot, store: store, key: key)

      assert %Session{refresh_jwt: "boot-refresh"} = SessionManager.session(pid)
      assert {:ok, _blob} = MemoryStore.fetch(@did, pid: store_pid)
    end

    test "retries persisting a freshly rotated session through a storage hiccup", %{
      store_pid: store_pid,
      key: key
    } do
      {:ok, flaky_pid} = FlakyStore.start_link(2)
      store = {FlakyStore, [pid: flaky_pid]}

      client = oauth_client()
      session = oauth_session(client, expires_at: System.system_time(:second) + 2)

      http = token_refresh_http("rt-2")

      {:ok, pid} =
        SessionManager.start_link(
          session: session,
          refresh_opts: [client: client, http: http],
          store: store,
          key: key,
          refresh_fraction: 0.1
        )

      assert_eventually(fn ->
        case FlakyStore.fetch(@did, pid: flaky_pid) do
          {:error, _} ->
            false

          {:ok, blob} ->
            match?(
              %OAuthSession{refresh_token: "rt-2"},
              blob |> Crypto.decrypt(key) |> elem(1) |> :erlang.binary_to_term()
            )
        end
      end)

      assert Process.alive?(pid)
    end

    test "keeps the freshly rotated session in memory when the store keeps failing", %{
      key: key
    } do
      {:ok, flaky_pid} = FlakyStore.start_link(100)
      store = {FlakyStore, [pid: flaky_pid]}

      client = oauth_client()
      session = oauth_session(client, expires_at: System.system_time(:second) + 2)

      http = token_refresh_http("rt-2")

      {:ok, pid} =
        SessionManager.start_link(
          session: session,
          refresh_opts: [client: client, http: http],
          store: store,
          key: key,
          refresh_fraction: 0.1
        )

      # The rotated tokens are only in memory: stopping the manager here
      # would make the restart replay the stale stored refresh token
      assert_eventually(fn -> SessionManager.session(pid).refresh_token == "rt-2" end)
      assert Process.alive?(pid)
    end
  end

  describe "logout" do
    test "revokes at the PDS, for app-password sessions" do
      test_pid = self()

      http =
        fake_http(fn :post, url, _opts ->
          send(test_pid, {:delete_session, url})
          {:ok, %{status: 200, body: "", headers: []}}
        end)

      session = app_password_session(service_url: "https://pds.test/xrpc")

      {:ok, pid} = SessionManager.start_link(session: session, refresh_opts: [http: http])
      ref = Process.monitor(pid)

      assert :ok = SessionManager.logout(pid)
      assert_receive {:delete_session, "https://pds.test/xrpc/com.atproto.server.deleteSession"}
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

      assert_received {:telemetry, [:proto_rune, :session, :revoke, :start], _, %{did: @did}}
      assert_received {:telemetry, [:proto_rune, :session, :revoke, :stop], _, %{did: @did}}
    end

    test "deletes the stored session, for app-password sessions", %{store: store, store_pid: store_pid, key: key} do
      http =
        fake_http(fn :post, _url, _opts ->
          {:ok, %{status: 200, body: "", headers: []}}
        end)

      session = app_password_session(service_url: "https://pds.test/xrpc")
      :ok = Security.save_session(session, key, store)

      {:ok, pid} = SessionManager.start_link(session: session, refresh_opts: [http: http], store: store, key: key)
      ref = Process.monitor(pid)

      assert :ok = SessionManager.logout(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
      assert {:error, :not_found} = MemoryStore.fetch(@did, pid: store_pid)
    end

    test "revokes at the authorization server, for OAuth sessions", %{store: store, store_pid: store_pid, key: key} do
      client = oauth_client()
      session = oauth_session(client)
      test_pid = self()

      http =
        fake_http(fn
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

      :ok = Security.save_session(session, key, store)

      {:ok, pid} =
        SessionManager.start_link(
          session: session,
          refresh_opts: [client: client, http: http],
          store: store,
          key: key
        )

      ref = Process.monitor(pid)

      assert :ok = SessionManager.logout(pid)
      assert_receive :revoked
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
      assert {:error, :not_found} = MemoryStore.fetch(@did, pid: store_pid)

      assert_received {:telemetry, [:proto_rune, :session, :revoke, :start], _, %{did: @did}}
      assert_received {:telemetry, [:proto_rune, :session, :revoke, :stop], _, %{did: @did}}
    end
  end

  describe "oauth sessions" do
    test "refreshes on schedule, rotates tokens and persists through the store", %{
      store: store,
      store_pid: store_pid,
      key: key
    } do
      client = oauth_client()
      session = oauth_session(client, expires_at: System.system_time(:second) + 2)

      http =
        fake_http(fn :post, @token_url, opts ->
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
          refresh_opts: [client: client, http: http],
          store: store,
          key: key,
          refresh_fraction: 0.1
        )

      assert_eventually(fn -> SessionManager.session(pid).access_token == "at-2" end)

      fresh = SessionManager.session(pid)
      assert fresh.refresh_token == "rt-2"
      assert fresh.dpop_nonce == "nonce-9"

      # The persisted blob is encrypted: the store never sees plaintext
      assert {:ok, blob} = MemoryStore.fetch(@did, pid: store_pid)
      assert {:ok, plaintext} = Crypto.decrypt(blob, key)
      assert %OAuthSession{access_token: "at-2", refresh_token: "rt-2"} = :erlang.binary_to_term(plaintext)

      assert_received {:telemetry, [:proto_rune, :session, :refresh, :start], _, %{did: @did}}
      assert_received {:telemetry, [:proto_rune, :session, :refresh, :stop], _, %{did: @did}}
    end

    test "stops normally and deletes the stored session on invalid_grant", %{
      store: store,
      store_pid: store_pid,
      key: key
    } do
      Process.flag(:trap_exit, true)

      client = oauth_client()
      session = oauth_session(client, expires_at: System.system_time(:second) + 2)

      http =
        fake_http(fn :post, @token_url, _opts ->
          {:ok,
           %{
             status: 400,
             body: %{"error" => "invalid_grant", "error_description" => "Refresh token replayed"},
             headers: []
           }}
        end)

      MemoryStore.put(@did, "stale-blob", pid: store_pid)

      {:ok, pid} =
        SessionManager.start_link(
          session: session,
          refresh_opts: [client: client, http: http],
          store: store,
          key: key,
          refresh_fraction: 0.1
        )

      assert_receive {:EXIT, ^pid, :normal}, 2_000
      assert {:error, :not_found} = MemoryStore.fetch(@did, pid: store_pid)

      assert_received {:telemetry, [:proto_rune, :session, :refresh, :stop], _,
                       %{did: @did, error: {:oauth_error, 400, %{"error" => "invalid_grant"}}}}
    end

    test "stops with a descriptive reason when the refresh fails transiently", %{
      store: store,
      key: key
    } do
      Process.flag(:trap_exit, true)

      client = oauth_client()
      session = oauth_session(client, expires_at: System.system_time(:second) + 2)

      http =
        fake_http(fn :post, @token_url, _opts ->
          {:ok, %{status: 500, body: %{"error" => "server_error"}, headers: []}}
        end)

      {:ok, pid} =
        SessionManager.start_link(
          session: session,
          refresh_opts: [client: client, http: http],
          store: store,
          key: key,
          refresh_fraction: 0.1
        )

      assert_receive {:EXIT, ^pid, {:refresh_failed, {:oauth_error, 500, %{"error" => "server_error"}}}},
                     2_000

      assert_received {:telemetry, [:proto_rune, :session, :refresh, :stop], _,
                       %{did: @did, error: {:oauth_error, 500, %{"error" => "server_error"}}}}
    end
  end

  defp jwt(exp) do
    header = Base.url_encode64(JSON.encode!(%{"alg" => "ES256"}), padding: false)
    payload = Base.url_encode64(JSON.encode!(%{"exp" => exp}), padding: false)
    "#{header}.#{payload}.sig"
  end

  defp app_password_session(opts \\ []) do
    %Session{
      access_jwt: jwt(@exp),
      refresh_jwt: Keyword.get(opts, :refresh_jwt, "rt-1"),
      did: @did,
      handle: "alice.test",
      service_url: Keyword.get(opts, :service_url, "https://pds.test/xrpc"),
      expires_at: Keyword.get(opts, :expires_at)
    }
  end

  defp oauth_client do
    {:ok, client} =
      Client.new(
        client_id: "https://myapp.test/oauth/client-metadata.json",
        redirect_uri: "https://myapp.test/oauth/callback"
      )

    client
  end

  defp oauth_session(client, opts \\ []) do
    %OAuthSession{
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

  defp token_refresh_http(new_refresh_token) do
    fake_http(fn :post, @token_url, _opts ->
      {:ok,
       %{
         status: 200,
         body: %{
           "access_token" => "at-2",
           "refresh_token" => new_refresh_token,
           "token_type" => "DPoP",
           "expires_in" => 3600,
           "sub" => @did
         },
         headers: []
       }}
    end)
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

  # Helpers
end
