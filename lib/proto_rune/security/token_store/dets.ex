defmodule ProtoRune.Security.TokenStore.Dets do
  @moduledoc """
  DETS-based `ProtoRune.Security.TokenStore` backend.

  Stores encrypted token blobs in a single `:dets` table file. DETS is
  part of the OTP standard library, so this backend has no extra
  dependencies. The table file is restricted to mode `0o600` after
  creation.

  The table is opened and closed on every call, so no process owns it
  between operations. Note that DETS allows only one process to have a
  given file open at a time: concurrent calls against the same path are
  serialized by the caller, not by this backend.

  ## Options

    * `:path` - path of the DETS table file. Defaults to
      `Path.join(:filename.basedir(:user_cache, "proto_rune"), "tokens.dets")`.

  ## Examples

      store = {ProtoRune.Security.TokenStore.Dets, path: "/var/myapp/tokens.dets"}
      :ok = ProtoRune.Security.save_session(session, key, store)
  """

  @behaviour ProtoRune.Security.TokenStore

  @impl true
  def put(id, blob, opts) when is_binary(id) and is_binary(blob) do
    with_table(opts, fn table -> :dets.insert(table, {id, blob}) end)
  end

  @impl true
  def fetch(id, opts) when is_binary(id) do
    with_table(opts, fn table ->
      case :dets.lookup(table, id) do
        [{^id, blob}] -> {:ok, blob}
        [] -> {:error, :not_found}
      end
    end)
  end

  @impl true
  def delete(id, opts) when is_binary(id) do
    with_table(opts, fn table -> :dets.delete(table, id) end)
  end

  defp with_table(opts, fun) do
    path = table_path(opts)

    with :ok <- File.mkdir_p(Path.dirname(path)),
         {:ok, table} <- open_table(path) do
      # Best effort: on filesystems without POSIX modes this is a no-op error.
      _ = File.chmod(path, 0o600)

      try do
        fun.(table)
      after
        :dets.close(table)
      end
    end
  end

  defp open_table(path) do
    case :dets.open_file(make_ref(), file: String.to_charlist(path), type: :set) do
      {:ok, table} -> {:ok, table}
      {:error, reason} -> {:error, reason}
    end
  end

  defp table_path(opts) do
    default = Path.join(to_string(:filename.basedir(:user_cache, "proto_rune")), "tokens.dets")

    opts
    |> Keyword.get(:path, default)
    |> Path.expand()
  end
end
