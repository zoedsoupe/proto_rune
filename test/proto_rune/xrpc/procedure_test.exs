defmodule ProtoRune.XRPC.ProcedureTest do
  use ExUnit.Case, async: true

  alias ProtoRune.XRPC.Procedure

  describe "new/1" do
    test "creates a procedure with method only" do
      proc = Procedure.new("com.atproto.server.createSession")

      assert proc.method == "com.atproto.server.createSession"
      assert proc.body == %{}
      assert proc.headers == %{}
      assert proc.parser == nil
      assert proc.base_url == nil
    end
  end

  describe "new/2" do
    test "creates a procedure with parser" do
      parser = %{identifier: {:required, :string}, password: {:required, :string}}
      proc = Procedure.new("com.atproto.server.createSession", from: parser)

      assert proc.method == "com.atproto.server.createSession"
      assert proc.parser == parser
      assert proc.base_url == nil
    end

    test "creates a procedure with base_url" do
      proc = Procedure.new("com.atproto.server.createSession", base_url: "https://custom.pds")

      assert proc.method == "com.atproto.server.createSession"
      assert proc.base_url == "https://custom.pds"
    end

    test "creates a procedure with both parser and base_url" do
      parser = %{identifier: {:required, :string}}
      proc = Procedure.new("com.atproto.server.createSession", from: parser, base_url: "https://custom.pds")

      assert proc.parser == parser
      assert proc.base_url == "https://custom.pds"
    end
  end

  describe "put_body/2" do
    test "validates and sets body with valid data" do
      parser = %{
        identifier: {:required, :string},
        password: {:required, :string}
      }

      proc = Procedure.new("com.atproto.server.createSession", from: parser)

      assert {:ok, updated_proc} =
               Procedure.put_body(proc, %{
                 identifier: "alice.bsky.social",
                 password: "secret"
               })

      assert updated_proc.body.identifier == "alice.bsky.social"
      assert updated_proc.body.password == "secret"
    end

    test "returns error with invalid data" do
      parser = %{
        identifier: {:required, :string},
        password: {:required, :string}
      }

      proc = Procedure.new("com.atproto.server.createSession", from: parser)

      # Missing required field
      assert {:error, _reason} = Procedure.put_body(proc, %{identifier: "alice.bsky.social"})
    end
  end

  describe "put_header/3" do
    test "adds a header to the procedure" do
      proc =
        "com.atproto.repo.createRecord"
        |> Procedure.new()
        |> Procedure.put_header(:authorization, "Bearer token123")

      assert proc.headers[:authorization] == "Bearer token123"
    end

    test "updates an existing header" do
      proc =
        "com.atproto.repo.createRecord"
        |> Procedure.new()
        |> Procedure.put_header(:authorization, "Bearer token123")
        |> Procedure.put_header(:authorization, "Bearer new_token")

      assert proc.headers[:authorization] == "Bearer new_token"
    end
  end

  describe "put_base_url/2" do
    test "sets the base_url" do
      proc =
        "com.atproto.server.createSession"
        |> Procedure.new()
        |> Procedure.put_base_url("https://custom.pds")

      assert proc.base_url == "https://custom.pds"
    end

    test "updates existing base_url" do
      proc =
        "com.atproto.server.createSession"
        |> Procedure.new(base_url: "https://old.pds")
        |> Procedure.put_base_url("https://new.pds")

      assert proc.base_url == "https://new.pds"
    end
  end

  describe "String.Chars protocol" do
    test "converts procedure to URL string" do
      proc = Procedure.new("com.atproto.server.createSession", base_url: "https://bsky.social/xrpc")

      url = to_string(proc)

      assert url == "https://bsky.social/xrpc/com.atproto.server.createSession"
    end

    test "uses default when base_url is nil" do
      proc = Procedure.new("com.atproto.server.createSession")

      url = to_string(proc)

      # Should use Config fallback - verify structure rather than exact value
      assert url =~ ~r|^https?://.*xrpc/com\.atproto\.server\.createSession$|
    end

    test "custom base_url is used correctly" do
      proc = Procedure.new("com.atproto.server.createSession", base_url: "https://my-pds.example.com/xrpc")

      url = to_string(proc)

      assert url == "https://my-pds.example.com/xrpc/com.atproto.server.createSession"
    end
  end
end
