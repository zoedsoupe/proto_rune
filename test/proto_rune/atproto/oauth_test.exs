defmodule ProtoRune.Atproto.OAuthTest do
  use ExUnit.Case, async: false

  alias ProtoRune.Atproto.Identity.Cache
  alias ProtoRune.Atproto.OAuth
  alias ProtoRune.Atproto.OAuth.Client
  alias ProtoRune.Atproto.OAuth.Session

  @fake_server __MODULE__.FakeHTTPServer

  @pds_url "https://pds.test"
  @issuer "https://auth.test"
  @par_url "https://auth.test/oauth/par"
  @token_url "https://auth.test/oauth/token"
  @authorize_url "https://auth.test/oauth/authorize"
  @did "did:plc:test123"

  defmodule FakeHTTP do
    @moduledoc false

    @behaviour ProtoRune.HTTPClient.Adapter

    @impl true
    def request(method, url, opts) do
      handler =
        Agent.get(ProtoRune.Atproto.OAuthTest.FakeHTTPServer, fn state ->
          Map.get(state, {:request, method, url})
        end)

      case handler do
        nil -> raise "unexpected request: #{method} #{url}"
        fun when is_function(fun, 1) -> fun.(opts)
        response -> response
      end
    end
  end

  setup do
    {:ok, _agent} = Agent.start_link(fn -> %{} end, name: @fake_server)

    previous = Application.get_env(:proto_rune, :http_client)
    Application.put_env(:proto_rune, :http_client, FakeHTTP)
    start_supervised!(Cache)

    on_exit(fn ->
      if previous do
        Application.put_env(:proto_rune, :http_client, previous)
      else
        Application.delete_env(:proto_rune, :http_client)
      end
    end)

    {:ok, client} =
      Client.new(
        client_id: "https://myapp.test/oauth/client-metadata.json",
        redirect_uri: "https://myapp.test/oauth/callback"
      )

    {:ok, client: client}
  end

  describe "authorization_url/3" do
    test "resolves a DID and builds the authorize URL from a PAR", %{client: client} do
      stub_authorization_server(%{client: client})

      assert {:ok, url, pending} = OAuth.authorization_url(client, @did)

      assert url =~ @authorize_url <> "?"
      assert url =~ "client_id=https%3A%2F%2Fmyapp.test%2Foauth%2Fclient-metadata.json"
      assert url =~ "request_uri=" <> URI.encode_www_form("urn:ietf:params:oauth:request_uri:req-1")

      assert pending.did == @did
      assert pending.handle == nil
      assert pending.service_url == @pds_url
      assert pending.issuer == @issuer
      assert pending.token_endpoint == @token_url
      assert pending.dpop_nonce == "nonce-1"
      assert is_binary(pending.state)
      assert is_binary(pending.code_verifier)
      assert pending.dpop_key == client.dpop_key
    end

    test "resolves a handle through the identity cache", %{client: client} do
      stub_authorization_server(%{client: client, login_hint: "alice.test"})

      expires_at = System.system_time(:millisecond) + 60_000
      :ets.insert(:handle_cache, {"alice.test", @did, %{expires_at: expires_at}})

      assert {:ok, _url, pending} = OAuth.authorization_url(client, "alice.test")
      assert pending.handle == "alice.test"
      assert pending.did == @did
    end

    test "retries PAR once with the server-provided DPoP nonce", %{client: client} do
      stub_identity()
      stub_metadata()

      stub(:post, @par_url, fn opts ->
        case next_call(:par_calls) do
          1 ->
            {:ok,
             %{
               status: 400,
               body: %{"error" => "use_dpop_nonce"},
               headers: [{"dpop-nonce", "nonce-x"}]
             }}

          2 ->
            proof = dpop_header(opts)
            claims = proof |> String.split(".") |> Enum.at(1) |> decode_segment()

            assert claims["nonce"] == "nonce-x"
            assert_valid_proof(proof, client.dpop_key, @par_url)

            {:ok,
             %{
               status: 201,
               body: %{"request_uri" => "urn:ietf:params:oauth:request_uri:req-2", "expires_in" => 299},
               headers: [{"dpop-nonce", "nonce-y"}]
             }}
        end
      end)

      assert {:ok, _url, pending} = OAuth.authorization_url(client, @did)
      assert pending.dpop_nonce == "nonce-y"
    end

    test "returns an error for invalid identifiers", %{client: client} do
      assert {:error, :invalid_identifier} = OAuth.authorization_url(client, "not a handle")
    end

    test "returns an error when the DID document has no PDS", %{client: client} do
      stub(:get, "https://plc.directory/#{@did}", %{
        status: 200,
        body: JSON.encode!(%{"id" => @did, "service" => []})
      })

      assert {:error, :pds_not_found} = OAuth.authorization_url(client, @did)
    end

    test "returns an error when protected resource metadata is malformed", %{client: client} do
      stub_identity()

      stub(:get, @pds_url <> "/.well-known/oauth-protected-resource", %{
        status: 200,
        body: %{"resource" => @pds_url}
      })

      assert {:error, :invalid_protected_resource_metadata} = OAuth.authorization_url(client, @did)
    end

    test "returns an error when the metadata issuer does not match", %{client: client} do
      stub_identity()
      stub_protected_resource()

      stub(:get, @issuer <> "/.well-known/oauth-authorization-server", %{
        status: 200,
        body:
          authorization_server_metadata(%{
            "issuer" => "https://other.test"
          })
      })

      assert {:error, :issuer_mismatch} = OAuth.authorization_url(client, @did)
    end
  end

  describe "exchange_code/3" do
    test "exchanges the code for a DPoP-bound session", %{client: client} do
      pending = pending(client)

      stub(:post, @token_url, fn opts ->
        form = opts[:form]

        assert form["grant_type"] == "authorization_code"
        assert form["code"] == "code-123"
        assert form["redirect_uri"] == client.redirect_uri
        assert form["client_id"] == client.client_id
        assert form["code_verifier"] == pending.code_verifier

        proof = dpop_header(opts)
        claims = proof |> String.split(".") |> Enum.at(1) |> decode_segment()

        assert claims["nonce"] == "nonce-1"
        assert_valid_proof(proof, client.dpop_key, @token_url)

        {:ok,
         %{
           status: 200,
           body: %{
             "access_token" => "at-1",
             "refresh_token" => "rt-1",
             "token_type" => "DPoP",
             "expires_in" => 3600,
             "sub" => @did,
             "scope" => "atproto transition:generic"
           },
           headers: [{"dpop-nonce", "nonce-2"}]
         }}
      end)

      params = %{"code" => "code-123", "state" => pending.state, "iss" => @issuer}

      assert {:ok, %Session{} = session} = OAuth.exchange_code(client, pending, params)

      assert session.did == @did
      assert session.access_token == "at-1"
      assert session.refresh_token == "rt-1"
      assert session.token_type == "DPoP"
      assert session.scope == "atproto transition:generic"
      assert session.service_url == @pds_url
      assert session.issuer == @issuer
      assert session.token_endpoint == @token_url
      assert session.dpop_nonce == "nonce-2"
      assert session.dpop_key == client.dpop_key
      assert session.expires_at > System.system_time(:second)
    end

    test "accepts atom-keyed callback params", %{client: client} do
      pending = pending(client)
      stub_token_response()

      params = %{code: "code-123", state: pending.state}

      assert {:ok, %Session{}} = OAuth.exchange_code(client, pending, params)
    end

    test "rejects a mismatched state", %{client: client} do
      pending = pending(client)

      assert {:error, :state_mismatch} =
               OAuth.exchange_code(client, pending, %{"code" => "code-123", "state" => "forged"})
    end

    test "rejects a mismatched issuer", %{client: client} do
      pending = pending(client)

      params = %{"code" => "code-123", "state" => pending.state, "iss" => "https://evil.test"}

      assert {:error, :issuer_mismatch} = OAuth.exchange_code(client, pending, params)
    end

    test "rejects callbacks without a code", %{client: client} do
      pending = pending(client)

      assert {:error, :missing_code} =
               OAuth.exchange_code(client, pending, %{"state" => pending.state, "error" => "access_denied"})
    end

    test "propagates token endpoint errors", %{client: client} do
      pending = pending(client)

      stub(:post, @token_url, %{
        status: 400,
        body: %{"error" => "invalid_grant"},
        headers: []
      })

      assert {:error, {:oauth_error, 400, %{"error" => "invalid_grant"}}} =
               OAuth.exchange_code(client, pending, %{"code" => "bad", "state" => pending.state})
    end
  end

  describe "refresh/2" do
    test "refreshes tokens and rotates the refresh token", %{client: client} do
      session = session(client)

      stub(:post, @token_url, fn opts ->
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
           headers: [{"dpop-nonce", "nonce-3"}]
         }}
      end)

      assert {:ok, fresh} = OAuth.refresh(client, session)

      assert fresh.access_token == "at-2"
      assert fresh.refresh_token == "rt-2"
      assert fresh.dpop_nonce == "nonce-3"
      assert fresh.service_url == session.service_url
      assert fresh.issuer == session.issuer
    end

    test "keeps the previous refresh token when none is issued", %{client: client} do
      session = session(client)

      stub(:post, @token_url, %{
        status: 200,
        body: %{"access_token" => "at-2", "token_type" => "DPoP", "sub" => @did},
        headers: []
      })

      assert {:ok, fresh} = OAuth.refresh(client, session)
      assert fresh.refresh_token == "rt-1"
    end

    test "returns an error without a refresh token", %{client: client} do
      session = %{session(client) | refresh_token: nil}

      assert {:error, :missing_refresh_token} = OAuth.refresh(client, session)
    end
  end

  # Helpers

  defp stub(method, url, response) when is_map(response) do
    stub(method, url, {:ok, response})
  end

  defp stub(method, url, response) do
    Agent.update(@fake_server, &Map.put(&1, {:request, method, url}, response))
  end

  defp next_call(counter) do
    Agent.get_and_update(@fake_server, fn state ->
      count = Map.get(state, counter, 0) + 1
      {count, Map.put(state, counter, count)}
    end)
  end

  defp stub_authorization_server(%{client: client} = context) do
    stub_identity()
    stub_metadata()

    stub(:post, @par_url, fn opts ->
      form = opts[:form]

      assert form["response_type"] == "code"
      assert form["client_id"] == client.client_id
      assert form["redirect_uri"] == client.redirect_uri
      assert form["scope"] == "atproto transition:generic"
      assert form["code_challenge_method"] == "S256"
      assert is_binary(form["code_challenge"])
      assert is_binary(form["state"])
      assert form["login_hint"] == Map.get(context, :login_hint, @did)

      assert_valid_proof(dpop_header(opts), client.dpop_key, @par_url)

      {:ok,
       %{
         status: 201,
         body: %{"request_uri" => "urn:ietf:params:oauth:request_uri:req-1", "expires_in" => 299},
         headers: [{"dpop-nonce", "nonce-1"}]
       }}
    end)
  end

  defp stub_identity do
    stub(:get, "https://plc.directory/#{@did}", %{
      status: 200,
      body:
        JSON.encode!(%{
          "id" => @did,
          "alsoKnownAs" => ["at://alice.test"],
          "service" => [
            %{
              "id" => "#atproto_pds",
              "type" => "AtprotoPersonalDataServer",
              "serviceEndpoint" => @pds_url
            }
          ],
          "verificationMethod" => []
        })
    })
  end

  defp stub_metadata do
    stub_protected_resource()

    stub(:get, @issuer <> "/.well-known/oauth-authorization-server", %{
      status: 200,
      body: authorization_server_metadata()
    })
  end

  defp stub_protected_resource do
    stub(:get, @pds_url <> "/.well-known/oauth-protected-resource", %{
      status: 200,
      body: %{"resource" => @pds_url, "authorization_servers" => [@issuer]}
    })
  end

  defp authorization_server_metadata(overrides \\ %{}) do
    Map.merge(
      %{
        "issuer" => @issuer,
        "authorization_endpoint" => @authorize_url,
        "token_endpoint" => @token_url,
        "pushed_authorization_request_endpoint" => @par_url
      },
      overrides
    )
  end

  defp stub_token_response do
    stub(:post, @token_url, %{
      status: 200,
      body: %{
        "access_token" => "at-1",
        "refresh_token" => "rt-1",
        "token_type" => "DPoP",
        "expires_in" => 3600,
        "sub" => @did
      },
      headers: []
    })
  end

  defp pending(client) do
    %{
      did: @did,
      handle: "alice.test",
      service_url: @pds_url,
      issuer: @issuer,
      state: "state-123",
      code_verifier: "verifier-123",
      dpop_key: client.dpop_key,
      dpop_jwk: client.dpop_jwk,
      dpop_nonce: "nonce-1",
      token_endpoint: @token_url
    }
  end

  defp session(client) do
    %Session{
      did: @did,
      handle: "alice.test",
      access_token: "at-1",
      refresh_token: "rt-1",
      token_type: "DPoP",
      scope: "atproto transition:generic",
      service_url: @pds_url,
      issuer: @issuer,
      token_endpoint: @token_url,
      dpop_key: client.dpop_key,
      dpop_jwk: client.dpop_jwk,
      dpop_nonce: "nonce-2"
    }
  end

  defp dpop_header(opts) do
    opts[:headers]
    |> Enum.find(fn {key, _value} -> key == "dpop" end)
    |> elem(1)
  end

  defp decode_segment(segment) do
    segment
    |> Base.url_decode64!(padding: false)
    |> JSON.decode!()
  end

  defp assert_valid_proof(proof, private, expected_url) do
    [encoded_header, encoded_claims, encoded_sig] = String.split(proof, ".")
    claims = decode_segment(encoded_claims)

    assert claims["htu"] == expected_url
    assert claims["htm"] == "POST"

    <<r::unsigned-big-256, s::unsigned-big-256>> = Base.url_decode64!(encoded_sig, padding: false)
    der = :public_key.der_encode(:"ECDSA-Sig-Value", {:"ECDSA-Sig-Value", r, s})
    {public, ^private} = :crypto.generate_key(:ecdh, :secp256r1, private)

    assert :crypto.verify(:ecdsa, :sha256, encoded_header <> "." <> encoded_claims, der, [
             public,
             :secp256r1
           ])
  end
end
