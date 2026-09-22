defmodule ProtoRune.Case do
  @moduledoc """
  Yeah, in house string casing
  """

  def snakelize(binary), do: snakelize(binary, true)

  # `first` tracks the head of the string so a leading uppercase letter is
  # downcased without a spurious leading underscore ("RecordNotFound"
  # becomes "record_not_found", not "_record_not_found").
  defp snakelize(<<>>, _first), do: <<>>

  defp snakelize(<<hd::utf8, rest::binary>>, first) do
    if hd in ?A..?Z do
      prefix = if first, do: <<>>, else: <<?_>>
      prefix <> <<hd + 32>> <> snakelize(rest, false)
    else
      <<hd::utf8>> <> snakelize(rest, false)
    end
  end

  def camelize(<<>>), do: <<>>

  def camelize(<<"_", next::binary-size(1), rest::binary>>) do
    String.upcase(next) <> camelize(rest)
  end

  def camelize(<<hd::binary-size(1), rest::binary>>) do
    hd <> camelize(rest)
  end

  def camelize_enum(enum) do
    apply_case_enum(enum, &camelize/1)
  end

  def snakelize_enum(enum) do
    apply_case_enum(enum, &snakelize/1)
  end

  defp apply_case_enum(map, case_fun) when is_map(map) do
    Map.new(map, &apply_case_enum_element(&1, case_fun))
  end

  defp apply_case_enum(list, case_fun) when is_list(list) do
    Enum.map(list, &apply_case_enum(&1, case_fun))
  end

  defp apply_case_enum(elem, _), do: elem

  defp apply_case_enum_element({k, v}, case) do
    case_key = k |> to_string() |> case.() |> intern()
    {case_key, apply_case_enum(v, case)}
  end

  # Server responses carry arbitrary keys; interning them blindly would let
  # a hostile server exhaust the atom table. Known keys (those already
  # referenced in the codebase or in Peri schemas) become atoms as before,
  # anything else stays a string.
  defp intern(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> key
  end
end
