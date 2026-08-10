defmodule ProtoRune.SecurityTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Atproto.Session
  alias ProtoRune.Security
  alias ProtoRune.Security.Crypto
  alias ProtoRune.Security.TokenStore.Dets

  defmodule InMemoryStore do
    @moduledoc false
    @behaviour ProtoRune.Security.TokenStore

    @impl true
    def put(id, blob, opts) do
      Agent.update(agent!(opts), &Map.put(&1, id, blob))
    end

    @impl true
    def fetch(id, opts) do
      case Agent.get(agent!(opts), &Map.fetch(&1, id)) do
        {:ok, blob} -> {:ok, blob}
        :error -> {:error, :not_found}
      end
    end

    @impl true
    def delete(id, opts) do
      Agent.update(agent!(opts), &Map.delete(&1, id))
    end

    defp agent!(opts) do
      Keyword.fetch!(opts, :agent)
    end
  end

  setup do
    path = Path.join(System.tmp_dir!(), "proto_rune_security_test_#{System.unique_integer([:positive])}.dets")
    on_exit(fn -> File.rm(path) end)

    %{
      key: Security.generate_key(),
      dets_store: {Dets, [path: path]}
    }
  end

  defp session(did \\ "did:plc:alice") do
    %Session{
      access_jwt: "access.jwt",
      refresh_jwt: "refresh.jwt",
      handle: "alice.bsky.social",
      did: did,
      service_url: "https://pds.example.com"
    }
  end

  describe "save_session/3 and load_session/3" do
    test "roundtrip a session through the default Dets backend", %{key: key, dets_store: store} do
      session = session()

      assert :ok = Security.save_session(session, key, store)
      assert {:ok, ^session} = Security.load_session(session.did, key, store)
    end

    test "roundtrip a session through a custom backend", %{key: key} do
      {:ok, agent} = Agent.start_link(fn -> %{} end)
      store = {InMemoryStore, [agent: agent]}
      session = session()

      assert :ok = Security.save_session(session, key, store)
      assert {:ok, ^session} = Security.load_session(session.did, key, store)
    end

    test "does not store plaintext tokens", %{key: key, dets_store: store} do
      session = session()

      assert :ok = Security.save_session(session, key, store)
      assert {:ok, blob} = Dets.fetch(session.did, elem(store, 1))
      refute blob =~ "access.jwt"
    end

    test "fails to load with a different key", %{key: key, dets_store: store} do
      session = session()

      assert :ok = Security.save_session(session, key, store)

      assert {:error, :decrypt_failed} =
               Security.load_session(session.did, Security.generate_key(), store)
    end

    test "returns :not_found for an unknown did", %{key: key, dets_store: store} do
      assert {:error, :not_found} = Security.load_session("did:plc:missing", key, store)
    end

    test "returns :invalid_session when the payload is not a session", %{key: key, dets_store: store} do
      {backend, opts} = store
      {:ok, blob} = Crypto.encrypt(:erlang.term_to_binary(%{not: :a_session}), key)
      :ok = backend.put("did:plc:bogus", blob, opts)

      assert {:error, :invalid_session} = Security.load_session("did:plc:bogus", key, store)
    end
  end

  describe "delete_session/2" do
    test "removes a stored session", %{key: key, dets_store: store} do
      session = session()

      assert :ok = Security.save_session(session, key, store)
      assert :ok = Security.delete_session(session.did, store)
      assert {:error, :not_found} = Security.load_session(session.did, key, store)
    end

    test "returns :ok for a missing session", %{dets_store: store} do
      assert :ok = Security.delete_session("did:plc:missing", store)
    end
  end

  describe "key helpers" do
    test "delegate to Crypto" do
      key = Security.generate_key()

      assert byte_size(key) == 32
      assert {:ok, ^key} = key |> Security.encode_key() |> Security.decode_key()
    end
  end
end
