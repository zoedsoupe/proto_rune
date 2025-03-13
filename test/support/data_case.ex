defmodule ProtoRune.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  validation of data structures and changesets.

  You may define functions here to be used as helpers in
  tests requiring changeset validation.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Ecto
      import Ecto.Changeset
      import ProtoRune.DataCase
    end
  end

  @doc """
  Helper for translating changeset errors into a map of error messages.
  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
