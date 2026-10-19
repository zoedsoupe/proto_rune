defmodule ProtoRune.HTTPClient.SSRF do
  @moduledoc """
  Guarded GET for URLs a stranger chose, plus the one redirect walker the
  identity fetches use.

  `DIDResolver`, `HandleResolver` and the OAuth metadata fetches request
  URLs derived from stranger-controlled identifiers (handles, DIDs, PDS
  and issuer URLs). A client that fetches any host a stranger names will
  fetch the cloud metadata address or a database on the same network. This
  module is the choke point for those fetches:

    * the scheme must be `https`, and a redirect may not downgrade it
    * the host is resolved before the request and every address it answers
      is refused when it lands anywhere private, loopback, link-local or
      otherwise unroutable
    * a redirect is followed explicitly, up to `@max_redirects` hops, and
      each hop's target is re-checked (Finch follows no redirects on its
      own, so nothing here happens implicitly)

  ## Opt-in

  The address guard is off by default so a localhost PDS keeps working.
  Turn it on globally:

      config :proto_rune, refuse_private_addresses: true

  or per call, through the `:http` options (this also overrides the global
  setting):

      Identity.resolve_did(did, http: [refuse_private_addresses: true])

  ## Known gaps

  * The lookup asks for A records only, so a host that publishes only an
    AAAA answer resolves to nothing here and is refused as unreachable.
    Literal IP hosts (v4 and v6) are classified directly instead.
  * The name is resolved twice, once here and once when Finch opens the
    connection, so a name whose answer changes between the two checks an
    address here and connects somewhere else. Pinning the connection to
    the checked address closes it and is not done: Finch does not expose
    the resolved address to the TLS layer.
  * There is no cap on the response size here; the fetches read bodies
    that are DID documents, and `ProtoRune.HTTPClient` bounds nothing.
  """

  alias ProtoRune.Config
  alias ProtoRune.HTTPClient

  @max_redirects 3

  @doc """
  GETs `url` under the guard and answers the raw response.

  Answers `{:ok, %{status: status, headers: headers, body: body}}` or
  `{:error, reason}`; a non-2xx status is a successful answer, the caller
  decides what it means. Redirects are followed up to `@max_redirects`
  hops. `opts` are the `ProtoRune.HTTPClient.request/3` options plus
  `:refuse_private_addresses` (see the module documentation).
  """
  @spec get(String.t(), keyword()) ::
          {:ok, %{status: pos_integer(), headers: [{String.t(), String.t()}], body: binary()}}
          | {:error, term()}
  def get(url, opts \\ []) when is_binary(url) do
    {refuse, opts} = Keyword.pop(opts, :refuse_private_addresses)
    refuse = guard_enabled?(refuse)
    uri = URI.parse(url)

    with :ok <- check_scheme(uri),
         :ok <- check_address(uri.host, refuse) do
      follow(uri, opts, refuse, @max_redirects)
    end
  end

  defp guard_enabled?(nil), do: Config.get(:refuse_private_addresses) == true
  defp guard_enabled?(override), do: override == true

  # A redirect is a second URL the attacker chose: it may not skip the
  # address check, downgrade the scheme, or be relative (only absolute
  # https locations are followed).
  defp follow(uri, opts, refuse, hops) do
    case HTTPClient.request(:get, URI.to_string(uri), opts) do
      {:ok, %{status: status} = resp} when status in 300..399 ->
        redirect(resp, opts, refuse, hops)

      other ->
        other
    end
  end

  defp redirect(_resp, _opts, _refuse, 0), do: {:error, :too_many_redirects}

  defp redirect(resp, opts, refuse, hops) do
    status = resp.status
    location = HTTPClient.get_header(resp.headers, "location")

    with {:ok, target} <- absolute_https(location, status),
         :ok <- check_address(target.host, refuse) do
      follow(target, opts, refuse, hops - 1)
    end
  end

  defp absolute_https(location, status) when not is_binary(location) or location == "",
    do: {:error, {:bad_redirect, status}}

  defp absolute_https(location, status) do
    case URI.parse(location) do
      %URI{scheme: "https", host: host} = uri when host not in [nil, ""] ->
        {:ok, uri}

      %URI{scheme: "http"} ->
        {:error, :insecure_redirect}

      _uri ->
        {:error, {:bad_redirect, status}}
    end
  end

  defp check_scheme(%URI{scheme: "https"}), do: :ok
  defp check_scheme(_uri), do: {:error, :insecure_scheme}

  defp check_address(_host, false), do: :ok
  defp check_address(host, true) when host in [nil, ""], do: {:error, :nxdomain}

  defp check_address(host, true) when is_binary(host) do
    name = String.trim(host, "[]")

    # A literal IP has no DNS answer to check, so classify it directly.
    case :inet.parse_address(String.to_charlist(name)) do
      {:ok, address} ->
        if public?(address), do: :ok, else: {:error, :forbidden_address}

      {:error, _} ->
        case :inet_res.lookup(String.to_charlist(host), :in, :a) do
          [] ->
            {:error, :nxdomain}

          addresses ->
            if Enum.all?(addresses, &public?/1), do: :ok, else: {:error, :forbidden_address}
        end
    end
  end

  # Anything not routable on the public internet. A DID document is
  # published on the public web by definition, so a private answer to the
  # name means the name was chosen to reach something else.
  defp public?({0, _, _, _}), do: false
  defp public?({10, _, _, _}), do: false
  defp public?({100, a, _, _}) when a in 64..127, do: false
  defp public?({127, _, _, _}), do: false
  defp public?({169, 254, _, _}), do: false
  defp public?({172, a, _, _}) when a in 16..31, do: false
  defp public?({192, 0, 0, _}), do: false
  defp public?({192, 0, 2, _}), do: false
  defp public?({192, 168, _, _}), do: false
  defp public?({198, 18, _, _}), do: false
  defp public?({198, 51, 100, _}), do: false
  defp public?({203, 0, 113, _}), do: false
  defp public?({224, _, _, _}), do: false
  defp public?({240, _, _, _}), do: false
  defp public?({_, _, _, _}), do: true

  defp public?({0, 0, 0, 0, 0, 0, 0, 0}), do: false
  defp public?({0, 0, 0, 0, 0, 0, 0, 1}), do: false

  # v4-mapped and v4-compatible v6 answers are the v4 they name
  defp public?({0, 0, 0, 0, 0, w, a, b}) when w in [0, 0xFFFF] do
    public?({div(a, 0x100), rem(a, 0x100), div(b, 0x100), rem(b, 0x100)})
  end

  defp public?({0xFE80, _, _, _, _, _, _, _}), do: false
  defp public?({w, _, _, _, _, _, _, _}) when w in 0xFC00..0xFDFF, do: false
  defp public?({0x2001, 0xDB8, _, _, _, _, _, _}), do: false
  defp public?({_, _, _, _, _, _, _, _}), do: true
end
