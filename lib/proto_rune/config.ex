defmodule ProtoRune.Config do
  @moduledoc """
  The `ProtoRune.Config` module provides configuration options for the ProtoRune library.
  """

  import Kernel, except: [get_in: 1]

  @doc """
  Gets a configuration value by key.
  """
  def get(key) do
    Application.get_env(:proto_rune, key)
  end

  @doc """
  Gets a configuration value by key and path.
  """
  def get_in([key | path]) when is_list(path) do
    :proto_rune
    |> Application.get_env(key)
    |> get_in(path)
  end
end
