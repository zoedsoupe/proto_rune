defmodule ProtoRune.Atproto.Identity.DIDResolverTest do
  use ProtoRune.TestCase, async: true

  alias ProtoRune.Atproto.Identity.DIDResolver

  @did "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
  @other_did "did:plc:impersonated000000000000000"

  defp did_document_body(did) do
    JSON.encode!(%{
      "@context" => ["https://www.w3.org/ns/did/v1"],
      "id" => did,
      "alsoKnownAs" => ["at://alice.test"],
      "verificationMethod" => [
        %{
          "id" => did <> "#atproto",
          "type" => "Multikey",
          "controller" => did,
          "publicKeyMultibase" => "zQ3shuCX5VxUghxi8JH1jgUhuFjNrnPuH4xa8GFqgNN9yE9JV"
        }
      ],
      "service" => [
        %{
          "id" => "#atproto_pds",
          "type" => "AtprotoPersonalDataServer",
          "serviceEndpoint" => "https://pds.test"
        }
      ]
    })
  end

  describe "impersonation check" do
    test "rejects a PLC document whose id is another DID" do
      http =
        fake_http(fn :get, _url, _opts ->
          {:ok, %{status: 200, body: did_document_body(@other_did), headers: []}}
        end)

      assert {:error, :did_mismatch} = DIDResolver.resolve_plc(@did, retry_count: 0, http: http)
    end

    test "rejects a did:web document whose id is another DID" do
      http =
        fake_http(fn :get, "https://alice.test/.well-known/did.json", _opts ->
          {:ok, %{status: 200, body: did_document_body(@other_did), headers: []}}
        end)

      assert {:error, :did_mismatch} = DIDResolver.resolve_web("did:web:alice.test", retry_count: 0, http: http)
    end

    test "rejects a document without an id" do
      http =
        fake_http(fn :get, _url, _opts ->
          {:ok, %{status: 200, body: JSON.encode!(%{"alsoKnownAs" => ["at://alice.test"]}), headers: []}}
        end)

      assert {:error, :invalid_format} = DIDResolver.resolve_plc(@did, retry_count: 0, http: http)
    end

    test "accepts a PLC document whose id matches the resolved DID" do
      http =
        fake_http(fn :get, _url, _opts ->
          {:ok, %{status: 200, body: did_document_body(@did), headers: []}}
        end)

      assert {:ok, doc} = DIDResolver.resolve_plc(@did, retry_count: 0, http: http)
      assert doc.id == @did
      assert [%{service_endpoint: "https://pds.test"}] = doc.service
    end

    test "accepts a did:web document whose id matches the resolved DID" do
      http =
        fake_http(fn :get, "https://alice.test/.well-known/did.json", _opts ->
          {:ok, %{status: 200, body: did_document_body("did:web:alice.test"), headers: []}}
        end)

      assert {:ok, doc} = DIDResolver.resolve_web("did:web:alice.test", retry_count: 0, http: http)
      assert doc.id == "did:web:alice.test"
    end
  end
end
