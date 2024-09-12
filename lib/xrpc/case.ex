defmodule XRPC.Case do
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
end
