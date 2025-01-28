defmodule ProtoRune.Atproto.Session do
  @moduledoc false

  @t %{
    access_jwt: {:required, :string},
    refresh_jwt: {:required, :string},
    handle: {:required, :string},
    did: {:required, :string},
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

  def parse(data) do
    {:ok, struct(__MODULE__, data)}
  end
end
