defmodule ProtoRune.HTTPClient.SSRFTest do
  @moduledoc """
  Tests for the opt-in private-address guard and the explicit redirect
  walker, against the fake adapter (no DNS, no live sockets): literal IP
  hosts classify without a lookup, so every case here is deterministic.
  """

  use ProtoRune.TestCase, async: true

  alias ProtoRune.HTTPClient.SSRF

  @ok {:ok, %{status: 200, headers: [], body: "x"}}

  # fake adapter router: one response per URL, unexpected URLs fail loudly
  defp router(routes) do
    fake_http(fn :get, url, _opts ->
      case Map.fetch(routes, url) do
        {:ok, response} -> response
        :error -> raise "unexpected request: #{url}"
      end
    end)
  end

  describe "address guard" do
    test "is off by default: a private host is fetched" do
      http = router(%{"https://127.0.0.1/doc" => @ok})

      assert {:ok, %{status: 200}} = SSRF.get("https://127.0.0.1/doc", http)
    end

    test "refuses loopback, private and link-local hosts when enabled per call" do
      for host <- [
            "127.0.0.1",
            "10.0.0.5",
            "192.168.1.1",
            "172.16.0.9",
            "169.254.169.254",
            "100.64.0.1",
            "0.0.0.0",
            "224.0.0.1"
          ] do
        # the guard must refuse before any request is issued
        http = fake_http(fn _m, _url, _opts -> flunk("request issued for #{host}") end)

        assert {:error, :forbidden_address} =
                 SSRF.get("https://#{host}/doc", [refuse_private_addresses: true] ++ http),
               "#{host} is not refused"
      end
    end

    test "classifies literal ipv6 hosts" do
      for host <- ["[::1]", "[fe80::1]", "[fc00::1]", "[fd12::1]", "[::ffff:127.0.0.1]"] do
        http = fake_http(fn _m, _url, _opts -> flunk("request issued for #{host}") end)

        assert {:error, :forbidden_address} =
                 SSRF.get("https://#{host}/doc", [refuse_private_addresses: true] ++ http),
               "#{host} is not refused"
      end
    end

    test "fetches public hosts when enabled" do
      http = router(%{"https://93.184.216.34/doc" => @ok})

      assert {:ok, %{status: 200}} =
               SSRF.get("https://93.184.216.34/doc", [refuse_private_addresses: true] ++ http)
    end

    test "is enabled through the global config" do
      put_env(:refuse_private_addresses, true)
      http = fake_http(fn _m, _url, _opts -> flunk("request issued") end)

      assert {:error, :forbidden_address} = SSRF.get("https://127.0.0.1/doc", http)
    end

    test "a per-call false overrides the global config" do
      put_env(:refuse_private_addresses, true)
      http = router(%{"https://127.0.0.1/doc" => @ok})

      assert {:ok, %{status: 200}} =
               SSRF.get("https://127.0.0.1/doc", [refuse_private_addresses: false] ++ http)
    end
  end

  describe "scheme check" do
    test "refuses non-https urls" do
      assert {:error, :insecure_scheme} = SSRF.get("http://93.184.216.34/doc", fake_http(fn _m, _u, _o -> @ok end))
    end
  end

  describe "redirect walker" do
    test "follows absolute https redirects within the hop budget" do
      http =
        router(%{
          "https://93.184.216.34/doc" =>
            {:ok, %{status: 302, headers: [{"location", "https://93.184.216.34/moved"}], body: ""}},
          "https://93.184.216.34/moved" => @ok
        })

      assert {:ok, %{status: 200}} =
               SSRF.get("https://93.184.216.34/doc", [refuse_private_addresses: true] ++ http)
    end

    test "re-checks each hop's address" do
      http =
        router(%{
          "https://93.184.216.34/doc" =>
            {:ok, %{status: 301, headers: [{"location", "https://127.0.0.1/secret"}], body: ""}}
        })

      assert {:error, :forbidden_address} =
               SSRF.get("https://93.184.216.34/doc", [refuse_private_addresses: true] ++ http)
    end

    test "refuses a scheme downgrade" do
      http =
        router(%{
          "https://93.184.216.34/doc" =>
            {:ok, %{status: 302, headers: [{"location", "http://93.184.216.34/moved"}], body: ""}}
        })

      assert {:error, :insecure_redirect} = SSRF.get("https://93.184.216.34/doc", http)
    end

    test "refuses relative and missing locations" do
      for location <- [nil, "/moved"] do
        headers = if location, do: [{"location", location}], else: []

        http =
          router(%{
            "https://93.184.216.34/doc" => {:ok, %{status: 302, headers: headers, body: ""}}
          })

        assert {:error, {:bad_redirect, 302}} = SSRF.get("https://93.184.216.34/doc", http)
      end
    end

    test "stops at the hop budget" do
      redirect =
        {:ok, %{status: 302, headers: [{"location", "https://93.184.216.34/doc"}], body: ""}}

      http = router(%{"https://93.184.216.34/doc" => redirect})

      assert {:error, :too_many_redirects} = SSRF.get("https://93.184.216.34/doc", http)
    end
  end
end
