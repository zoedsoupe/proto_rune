defmodule ProtoRune.SessionTest do
  use ExUnit.Case, async: false

  alias ProtoRune.Atproto.OAuth.DPoP
  alias ProtoRune.Atproto.OAuth.Session, as: OAuthSession
  alias ProtoRune.Atproto.Repo
  alias ProtoRune.Atproto.Session

  defmodule HTTPStub do
    @moduledoc false

    @behaviour ProtoRune.HTTPClient.Adapter

    @impl true
    def request(method, url, opts) do
      handler = Application.fetch_env!(:proto_rune, :http_stub_handler)
      handler.(method, url, opts)
    end
  end

  @app_session %Session{
    access_jwt: "token123",
    refresh_jwt: "refresh123",
    did: "did:plc:test",
    handle: "alice.test",
    service_url: "https://pds.test/xrpc"
  }

  setup do
    Application.put_env(:proto_rune, :http_client, HTTPStub)

    on_exit(fn ->
      Application.delete_env(:proto_rune, :http_client)
      Application.delete_env(:proto_rune, :http_stub_handler)
    end)

    :ok
  end

  defp oauth_session(opts \\ []) do
    {dpop_key, dpop_jwk} = DPoP.generate_key()

    %OAuthSession{
      did: "did:plc:test",
      handle: "alice.test",
      access_token: "at-1",
      refresh_token: "rt-1",
      service_url: "https://pds.test",
      dpop_key: dpop_key,
      dpop_jwk: dpop_jwk,
      dpop_nonce: Keyword.get(opts, :dpop_nonce)
    }
  end

  describe "Atproto.Session behaviour" do
    test "service_url/1 returns the session's service_url" do
      assert ProtoRune.Session.service_url(@app_session) == "https://pds.test/xrpc"
    end

    test "authorization_headers/3 emits the Bearer access JWT and keeps the session" do
      assert {:ok, headers, @app_session} =
               ProtoRune.Session.authorization_headers(@app_session, "GET", "https://pds.test/xrpc/x.y")

      assert headers == %{"authorization" => "Bearer token123"}
    end
  end

  describe "OAuth.Session behaviour" do
    test "service_url/1 normalizes the PDS URL into an XRPC base URL" do
      assert ProtoRune.Session.service_url(oauth_session()) == "https://pds.test/xrpc"
    end

    test "authorization_headers/3 emits a DPoP-bound authorization header and proof" do
      session = oauth_session()
      url = "https://pds.test/xrpc/app.bsky.actor.getProfile"

      assert {:ok, headers, ^session} = ProtoRune.Session.authorization_headers(session, "GET", url)

      assert headers["authorization"] == "DPoP at-1"
      assert_valid_proof(headers["dpop"], session, "GET", url)
    end

    test "authorization_headers/3 includes the DPoP nonce when the session carries one" do
      session = oauth_session(dpop_nonce: "nonce-1")
      url = "https://pds.test/xrpc/app.bsky.actor.getProfile"

      assert {:ok, headers, _session} = ProtoRune.Session.authorization_headers(session, "GET", url)

      claims = headers["dpop"] |> String.split(".") |> Enum.at(1) |> decode_segment()
      assert claims["nonce"] == "nonce-1"
    end
  end

  describe "XRPC calls with an OAuth session" do
    test "sends the DPoP authorization header and a valid proof" do
      session = oauth_session()
      test_pid = self()

      Application.put_env(:proto_rune, :http_stub_handler, fn method, url, opts ->
        send(test_pid, {:request, method, url, opts})
        {:ok, %{status: 200, body: %{"uri" => "at://did:plc:test/app.bsky.feed.post/abc"}}}
      end)

      assert {:ok, _} =
               Repo.get_record(session,
                 repo: "did:plc:test",
                 collection: "app.bsky.feed.post",
                 rkey: "abc"
               )

      assert_received {:request, :get, url, opts}
      assert url =~ "com.atproto.repo.getRecord"

      headers = Map.new(Keyword.get(opts, :headers, []))
      assert headers["authorization"] == "DPoP at-1"

      assert_valid_proof(
        headers["dpop"],
        session,
        "GET",
        "https://pds.test/xrpc/com.atproto.repo.getRecord"
      )
    end

    test "retries once with the server-provided DPoP nonce" do
      session = oauth_session()
      test_pid = self()
      {:ok, calls} = Agent.start_link(fn -> 0 end)

      Application.put_env(:proto_rune, :http_stub_handler, fn method, url, opts ->
        send(test_pid, {:request, method, url, opts})

        case Agent.get_and_update(calls, &{&1 + 1, &1 + 1}) do
          1 ->
            {:ok,
             %{
               status: 401,
               body: %{"error" => "use_dpop_nonce"},
               headers: [{"dpop-nonce", "nonce-r1"}]
             }}

          2 ->
            {:ok, %{status: 200, body: %{"uri" => "at://did:plc:test/app.bsky.feed.post/abc"}}}
        end
      end)

      assert {:ok, %{uri: _}} =
               Repo.get_record(session,
                 repo: "did:plc:test",
                 collection: "app.bsky.feed.post",
                 rkey: "abc"
               )

      assert_received {:request, :get, _url, first_opts}
      assert_received {:request, :get, _url, second_opts}
      assert Agent.get(calls, & &1) == 2

      first_headers = Map.new(Keyword.get(first_opts, :headers, []))
      second_headers = Map.new(Keyword.get(second_opts, :headers, []))

      first_claims = first_headers["dpop"] |> String.split(".") |> Enum.at(1) |> decode_segment()
      refute Map.has_key?(first_claims, "nonce")

      second_claims = second_headers["dpop"] |> String.split(".") |> Enum.at(1) |> decode_segment()
      assert second_claims["nonce"] == "nonce-r1"

      assert_valid_proof(
        second_headers["dpop"],
        session,
        "GET",
        "https://pds.test/xrpc/com.atproto.repo.getRecord"
      )
    end
  end

  defp decode_segment(segment) do
    segment
    |> Base.url_decode64!(padding: false)
    |> JSON.decode!()
  end

  defp assert_valid_proof(proof, session, expected_method, expected_url) do
    [encoded_header, encoded_claims, encoded_sig] = String.split(proof, ".")
    header = decode_segment(encoded_header)
    claims = decode_segment(encoded_claims)

    assert header["alg"] == "ES256"
    assert header["typ"] == "dpop+jwt"
    assert header["jwk"] == session.dpop_jwk

    assert claims["htm"] == expected_method
    assert claims["htu"] == expected_url
    assert claims["ath"] == Base.url_encode64(:crypto.hash(:sha256, session.access_token), padding: false)
    assert is_binary(claims["jti"])
    assert is_integer(claims["iat"])

    <<r::unsigned-big-256, s::unsigned-big-256>> = Base.url_decode64!(encoded_sig, padding: false)
    der = :public_key.der_encode(:"ECDSA-Sig-Value", {:"ECDSA-Sig-Value", r, s})
    {public, _private} = :crypto.generate_key(:ecdh, :secp256r1, session.dpop_key)

    assert :crypto.verify(:ecdsa, :sha256, encoded_header <> "." <> encoded_claims, der, [
             public,
             :secp256r1
           ])
  end
end
