defmodule ProtoRune.Atproto.IdentityTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Atproto.Identity

  require Identity

  describe "is_did/1 guard" do
    test "accepts valid did:plc format" do
      did = "did:plc:abc123xyz"
      assert Identity.is_did(did)
    end

    test "accepts valid did:web format" do
      did = "did:web:example.com"
      assert Identity.is_did(did)
    end

    test "rejects invalid formats" do
      refute Identity.is_did("not-a-did")
      refute Identity.is_did("did:")
      refute Identity.is_did("did:invalid:method")
      refute Identity.is_did(123)
      refute Identity.is_did(nil)
    end
  end

  describe "is_handle/1 guard" do
    test "accepts valid handle format" do
      assert Identity.is_handle("alice.bsky.social")
      assert Identity.is_handle("example.com")
      assert Identity.is_handle("sub.domain.example.com")
    end

    test "rejects invalid formats" do
      refute Identity.is_handle(".alice")
      refute Identity.is_handle("alice.")
      refute Identity.is_handle("-alice")
      refute Identity.is_handle("alice-")
      refute Identity.is_handle("a")
      refute Identity.is_handle(123)
      refute Identity.is_handle(nil)
    end
  end

  describe "valid_did?/1" do
    test "validates did:plc with proper identifier" do
      assert Identity.valid_did?("did:plc:abc123xyz")
      assert Identity.valid_did?("did:plc:a1b2c3")
    end

    test "validates did:web with domain" do
      assert Identity.valid_did?("did:web:example.com")
      assert Identity.valid_did?("did:web:sub.example.com")
    end

    test "validates did:web with port encoding" do
      assert Identity.valid_did?("did:web:example.com%3A8080")
    end

    test "rejects invalid DID formats" do
      refute Identity.valid_did?("not-a-did")
      refute Identity.valid_did?("did:")
      refute Identity.valid_did?("did:invalid:")
      refute Identity.valid_did?("did:plc:")
      refute Identity.valid_did?("did:plc:-invalid")
      refute Identity.valid_did?("did:plc:invalid-")
    end

    test "rejects unsupported DID methods" do
      refute Identity.valid_did?("did:key:abc123")
      refute Identity.valid_did?("did:ethr:0x123")
    end
  end

  describe "valid_handle?/1" do
    test "validates proper handle structure" do
      assert Identity.valid_handle?("alice.bsky.social")
      assert Identity.valid_handle?("bob.example.com")
      assert Identity.valid_handle?("sub.domain.example.com")
    end

    test "validates segments with hyphens" do
      assert Identity.valid_handle?("alice-wonder.bsky.social")
      assert Identity.valid_handle?("my-cool-app.example.com")
    end

    test "rejects handles with too short segments" do
      refute Identity.valid_handle?("..com")
      refute Identity.valid_handle?("a..com")
    end

    test "rejects handles with invalid characters" do
      refute Identity.valid_handle?("alice@example.com")
      refute Identity.valid_handle?("alice_wonder.bsky.social")
      refute Identity.valid_handle?("alice!.bsky.social")
    end

    test "rejects handles starting with hyphen in segments" do
      refute Identity.valid_handle?("-alice.bsky.social")
      refute Identity.valid_handle?("alice.-bsky.social")
    end

    test "rejects handles ending with hyphen in segments" do
      refute Identity.valid_handle?("alice-.bsky.social")
      refute Identity.valid_handle?("alice.bsky-.social")
    end

    test "rejects TLD starting with digit" do
      refute Identity.valid_handle?("alice.123")
      refute Identity.valid_handle?("example.9com")
    end

    test "requires at least 2 segments" do
      refute Identity.valid_handle?("alice")
      refute Identity.valid_handle?("localhost")
    end

    test "validates segments are within length limits" do
      # Each segment must be 1-63 chars
      long_segment = String.duplicate("a", 64)
      refute Identity.valid_handle?("#{long_segment}.example.com")

      ok_segment = String.duplicate("a", 63)
      assert Identity.valid_handle?("#{ok_segment}.example.com")
    end
  end
end
