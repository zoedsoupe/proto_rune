defmodule ProtoRune.XRPC.Error do
  @moduledoc false

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

  @type t :: %__MODULE__{
          message: String.t() | nil,
          reason: reason,
          http_status: integer
        }

  defstruct [:message, :reason, :http_status]

  def from(%Req.Response{} = response) do
    reason = maybe_get_reason(response)
    message = maybe_get_message(response)

    %__MODULE__{
      reason: reason,
      message: message,
      http_status: response.status
    }
  end

  defp maybe_get_reason(%{body: %{"error" => reason}}) do
    reason
    |> ProtoRune.Case.snakelize()
    |> String.replace_prefix("_", "")
    |> String.to_atom()
  end

  defp maybe_get_reason(%{status: 401}), do: :unauthorized
  defp maybe_get_reason(%{status: 404}), do: :not_found
  defp maybe_get_reason(%{status: 403}), do: :forbidden
  defp maybe_get_reason(%{status: 413}), do: :payload_too_large
  defp maybe_get_reason(%{status: 501}), do: :not_implemented
  defp maybe_get_reason(%{status: 502}), do: :bad_gateway
  defp maybe_get_reason(%{status: 503}), do: :service_unavailable
  defp maybe_get_reason(%{status: 504}), do: :gateway_timeout

  defp maybe_get_reason(%{status: 429} = resp) do
    retry_after = Req.Response.get_header(resp, "retry-after")
    {:rate_limited, retry_after}
  end

  defp maybe_get_message(response) do
    get_in(response.body["message"])
  end
end
