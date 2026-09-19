defmodule ProtoRune.XRPC.Error do
  @moduledoc """
  An XRPC error response.

  Every failed XRPC call returns `{:error, %Error{}}` with:

    * `:reason` - an atom derived from the lexicon error name
      (`"RecordNotFound"` becomes `:record_not_found`), or a generic atom
      derived from the HTTP status when the body carries no error name
    * `:message` - the human-readable message sent by the server, if any
    * `:http_status` - the response status code
    * `:retry_after` - the value of the `Retry-After` header, present on
      429 responses (`reason: :rate_limited`)

  ## Examples

      case Bsky.get_post_thread(session, uri) do
        {:ok, thread} -> thread
        {:error, %Error{reason: :not_found}} -> :gone
        {:error, %Error{reason: :rate_limited, retry_after: retry}} -> backoff(retry)
      end
  """

  @type reason ::
          :account_not_found
          | :account_takedown
          | :actor_not_found
          | :auth_factor_token_required
          | :bad_expiration
          | :bad_query_string
          | :blob_not_found
          | :block_not_found
          | :blocked_actor
          | :blocked_by_actor
          | :cannot_delete_self
          | :consumer_too_slow
          | :duplicate_create
          | :duplicate_template_name
          | :expired_token
          | :future_cursor
          | :handle_not_available
          | :head_not_found
          | :incompatible_did_doc
          | :invalid_email
          | :invalid_handle
          | :invalid_invite_code
          | :invalid_password
          | :invalid_swap
          | :invalid_token
          | :member_already_exists
          | :member_not_found
          | :not_found
          | :rate_limited
          | :record_not_found
          | :repo_deactivated
          | :repo_not_found
          | :repo_suspended
          | :repo_takendown
          | :set_not_found
          | :subject_has_action
          | :token_required
          | :unknown_feed
          | :unknown_list
          | :unresolvable_did
          | :unsupported_domain
          | atom()

  @type t :: %__MODULE__{
          message: String.t() | nil,
          reason: reason,
          http_status: integer,
          retry_after: String.t() | nil
        }

  defstruct [:message, :reason, :http_status, :retry_after]

  @doc false
  # Accepts any response map or struct with :status, :body and :headers,
  # so HTTP adapters are free to return their own response shape.
  def from(%{status: status, body: body} = response) do
    %__MODULE__{
      reason: reason(body, status),
      message: message(body),
      http_status: status,
      retry_after: retry_after(status, Map.get(response, :headers))
    }
  end

  defp reason(%{"error" => name}, _status) do
    name
    |> ProtoRune.Case.snakelize()
    |> String.replace_prefix("_", "")
    |> String.to_atom()
  end

  defp reason(_body, 401), do: :unauthorized
  defp reason(_body, 403), do: :forbidden
  defp reason(_body, 404), do: :not_found
  defp reason(_body, 413), do: :payload_too_large
  defp reason(_body, 429), do: :rate_limited
  defp reason(_body, 501), do: :not_implemented
  defp reason(_body, 502), do: :bad_gateway
  defp reason(_body, 503), do: :service_unavailable
  defp reason(_body, 504), do: :gateway_timeout
  defp reason(_body, _status), do: :unknown

  defp message(%{"message" => message}), do: message
  defp message(_body), do: nil

  defp retry_after(429, headers), do: get_header(headers, "retry-after")
  defp retry_after(_status, _headers), do: nil

  # Adapters deliver headers either as a list of tuples or as a map of
  # downcased names to value lists.
  defp get_header(headers, name) when is_list(headers) do
    Enum.find_value(headers, fn {key, value} ->
      if String.downcase(to_string(key)) == name, do: value
    end)
  end

  defp get_header(headers, name) when is_map(headers) do
    Enum.find_value(headers, fn {key, value} ->
      if String.downcase(to_string(key)) == name, do: value |> List.wrap() |> List.first()
    end)
  end

  defp get_header(_headers, _name), do: nil
end
