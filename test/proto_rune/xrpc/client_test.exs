defmodule ProtoRune.XRPC.ClientTest do
  use ExUnit.Case, async: false

  alias ProtoRune.XRPC.Client
  alias ProtoRune.XRPC.Procedure
  alias ProtoRune.XRPC.Query

  defmodule HTTPStub do
    @moduledoc false

    @behaviour ProtoRune.HTTPClient.Adapter

    @impl true
    def request(method, url, opts) do
      handler = Application.fetch_env!(:proto_rune, :http_stub_handler)
      handler.(method, url, opts)
    end
  end

  # Fake CAR bytes: any small non-JSON binary works as a fixture
  @car_bytes <<58, 162, 101, 118, 101, 114, 115, 105, 111, 110, 1>>

  setup do
    Application.put_env(:proto_rune, :http_client, HTTPStub)

    on_exit(fn ->
      Application.delete_env(:proto_rune, :http_client)
      Application.delete_env(:proto_rune, :http_stub_handler)
    end)

    :ok
  end

  defp stub_response(response) do
    Application.put_env(:proto_rune, :http_stub_handler, fn _method, _url, _opts ->
      {:ok, response}
    end)
  end

  describe "execute/1 with response: :auto" do
    test "decodes JSON when the response has no content-type header" do
      stub_response(%{status: 200, body: JSON.encode!(%{"handle" => "alice.bsky.social"})})

      query = Query.new("app.bsky.actor.getProfile")

      assert {:ok, %{handle: "alice.bsky.social"}} = Client.execute(query)
    end

    test "decodes JSON for an application/json content-type" do
      stub_response(%{
        status: 200,
        body: JSON.encode!(%{"handle" => "alice.bsky.social"}),
        headers: [{"content-type", "application/json"}]
      })

      query = Query.new("app.bsky.actor.getProfile")

      assert {:ok, %{handle: "alice.bsky.social"}} = Client.execute(query)
    end

    test "matches the media type only, ignoring charset parameters" do
      stub_response(%{
        status: 200,
        body: JSON.encode!(%{"handle" => "alice.bsky.social"}),
        headers: [{"Content-Type", "application/json; charset=utf-8"}]
      })

      query = Query.new("app.bsky.actor.getProfile")

      assert {:ok, %{handle: "alice.bsky.social"}} = Client.execute(query)
    end

    test "returns the raw body for a non-JSON content-type" do
      stub_response(%{
        status: 200,
        body: @car_bytes,
        headers: [{"content-type", "application/vnd.ipld.car"}]
      })

      query = Query.new("com.atproto.sync.getRepo")

      assert {:ok, %{content_type: "application/vnd.ipld.car", body: @car_bytes}} = Client.execute(query)
    end
  end

  describe "execute/1 with response: :json" do
    test "forces JSON decoding even for a non-JSON content-type" do
      stub_response(%{
        status: 200,
        body: JSON.encode!(%{"handle" => "alice.bsky.social"}),
        headers: [{"content-type", "text/plain"}]
      })

      query = Query.new("app.bsky.actor.getProfile", response: :json)

      assert {:ok, %{handle: "alice.bsky.social"}} = Client.execute(query)
    end
  end

  describe "execute/1 with response: :binary" do
    test "returns the raw body even for a JSON content-type" do
      body = JSON.encode!(%{"handle" => "alice.bsky.social"})

      stub_response(%{
        status: 200,
        body: body,
        headers: [{"content-type", "application/json"}]
      })

      query = Query.new("app.bsky.actor.getProfile", response: :binary)

      assert {:ok, %{content_type: "application/json", body: ^body}} = Client.execute(query)
    end

    test "returns a nil content_type when the response has no headers" do
      stub_response(%{status: 200, body: @car_bytes})

      proc =
        "com.atproto.sync.getRepo"
        |> Procedure.new(response: :binary)
        |> Procedure.put_raw_body(@car_bytes)

      assert {:ok, %{content_type: nil, body: @car_bytes}} = Client.execute(proc)
    end
  end

  describe "execute/1 error paths" do
    test "decodes the JSON error body even for a binary request" do
      # Error.from/1 matches on Req.Response, so the stub returns one
      stub_response(%Req.Response{
        status: 400,
        body: JSON.encode!(%{"error" => "InvalidRequest", "message" => "bad repo"})
      })

      query = Query.new("com.atproto.sync.getRepo", response: :binary)

      assert {:error, %ProtoRune.XRPC.Error{}} = Client.execute(query)
    end
  end
end
