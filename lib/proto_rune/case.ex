defmodule ProtoRune.Case do
  @moduledoc """
  Yeah, in house string casing
  """

  def snakelize(<<>>), do: <<>>

  def snakelize(<<hd::utf8, rest::binary>>) do
    if hd in ?A..?Z do
      <<?_>> <> <<hd + 32>> <> snakelize(rest)
    else
      <<hd>> <> snakelize(rest)
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
    case_key = k |> to_string() |> case.() |> String.to_atom()
    {case_key, apply_case_enum(v, case)}
  end
end
