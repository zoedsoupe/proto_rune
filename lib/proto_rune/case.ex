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
    normalized = apply_case_enum(enum, &camelize/1)

    if is_map(enum), do: Map.new(normalized), else: normalized
  end

  def snakelize_enum(enum) do
    normalized = apply_case_enum(enum, &snakelize/1)
    if is_map(enum), do: Map.new(normalized), else: normalized
  end

  defp apply_case_enum(enum, case_fun) when is_map(enum) or is_list(enum) do
    Enum.map(enum, &apply_case_enum_element(&1, case_fun))
  end

  defp apply_case_enum(elem, _), do: elem

  defp apply_case_enum_element({k, v}, case) when is_list(v) or is_map(v) do
    snake_key = case.(to_string(k))
    {String.to_atom(snake_key), Enum.map(v, &apply_case_enum(&1, case))}
  end

  defp apply_case_enum_element({k, v}, case) do
    snake_key = case.(to_string(k))
    {String.to_atom(snake_key), v}
  end
end
