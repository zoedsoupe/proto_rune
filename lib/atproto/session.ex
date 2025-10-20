defmodule ProtoRune.Atproto.Session do
  @moduledoc false

  @type t :: %__MODULE__{
          access_jwt: String.t(),
          refresh_jwt: String.t(),
          handle: String.t(),
          did: String.t(),
          service_url: String.t() | nil,
          active: boolean() | nil,
          email: String.t() | nil,
          email_auth_factor: boolean() | nil,
          email_confirmed: boolean() | nil,
          did_doc: map() | nil
        }

  @t %{
    access_jwt: {:required, :string},
    refresh_jwt: {:required, :string},
    handle: {:required, :string},
    did: {:required, :string},
    service_url: :string,
    active: :boolean,
    email: :string,
    email_auth_factor: :boolean,
    email_confirmed: :boolean,
    did_doc: %{
      id: :string,
      service:
        {:list,
         %{
           id: :string,
           type: :string,
           service_endpoint: :string
         }},
      "@context": {:list, :string},
      also_known_as: {:list, :string},
      verification_method:
        {:list,
         %{
           id: :string,
           type: :string,
           controller: :string,
           public_key_multibase: :string
         }}
    }
  }

  defstruct Map.keys(@t)

  @doc """
  Parses session data from the server response.

  Extracts the service URL from the DID document if available,
  allowing the session to carry its own service endpoint.

  ## Examples

      {:ok, session} = Session.parse(%{
        access_jwt: "...",
        refresh_jwt: "...",
        did: "did:plc:...",
        handle: "alice.bsky.social"
      })
  """
  def parse(data) when is_map(data) do
    # Extract service_url from did_doc if present
    service_url = extract_service_url(data)

    session_data = Map.put(data, :service_url, service_url)
    {:ok, struct(__MODULE__, session_data)}
  end

  defp extract_service_url(%{did_doc: %{service: services}}) when is_list(services) do
    # Look for ATProto PDS service endpoint
    case Enum.find(services, &(&1[:type] == "AtprotoPersonalDataServer")) do
      %{service_endpoint: url} -> url
      _ -> nil
    end
  end

  defp extract_service_url(_), do: nil
end
