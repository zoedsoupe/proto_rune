defmodule ProtoRune.Generator.ModuleBuilder do
  @moduledoc """
  Builds AST for generated Lexicon modules, leveraging Peri for schema validation.
  """

  @doc """
  Builds the AST for a Lexicon module based on the provided schema definition.
  """
  def build(lexicon_name, schema_def) do
    module_name = module_name_from_lexicon(lexicon_name)

    quote do
      defmodule unquote(module_name) do
        @moduledoc """
        Generated module for #{unquote(lexicon_name)} Lexicon.
        """

        import Peri

        # Define the schema using Peri's defschema
        defschema :t, unquote(Macro.escape(schema_def))

        @doc """
        Creates a changeset for validating data against this Lexicon's schema.
        """
        def changeset(data) do
          Peri.to_changeset!(get_schema(:t), data)
        end
      end
    end
  end

  @doc """
  Builds AST for resolving referenced Lexicons using Peri's get_schema.
  """
  def build_ref(ref_lexicon_name) do
    quote do
      defp resolve_ref(unquote(ref_lexicon_name)) do
        unquote(module_name_from_lexicon(ref_lexicon_name)).get_schema(:t)
      end
    end
  end

  # Converts a lexicon name like "app.bsky.feed.post" to a proper Elixir module name
  defp module_name_from_lexicon(lexicon_name) do
    parts = String.split(lexicon_name, ".")

    module_parts = Enum.map(parts, &Macro.camelize/1)

    Module.concat(["ProtoRune", "Lexicon"] ++ module_parts)
  end
end
