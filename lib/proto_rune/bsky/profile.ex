defmodule ProtoRune.Bsky.Profile do
  @moduledoc false

  defstruct [:handle, :did]

  @t %{handle: {:required, :string}, did: {:required, :string}}

  def parse(params) do
    with {:ok, params} <- Peri.validate(@t, params) do
      {:ok, struct(__MODULE__, params)}
    end
  end
end
