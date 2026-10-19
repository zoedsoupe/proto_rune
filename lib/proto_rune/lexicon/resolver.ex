defmodule ProtoRune.Lexicon.Resolver do
  @moduledoc """
  Inlines the `$ref` graph of a lexicon definition into self-contained JSON.

  Pure and total: it takes the parsed lexicon documents as data (the entries
  table built by `ProtoRune.Lexicon.Loader`), reads no registry, touches no
  process and never raises. The output is a JSON-shaped definition with every
  `"ref"` node replaced by the definition it names, which
  `ProtoRune.Lexicon.TypeMapper` then translates into a Peri schema term.

  Three ref spellings are followed:

    * `"#name"` - a def of the document the ref came from;
    * `"nsid"` - the `main` def of another lexicon;
    * `"nsid#name"` - a named def of another lexicon.

  Each node is resolved against the document it came from, not the one the
  walk started in: a `#link` inside a pulled-in definition means a def of
  that definition's own lexicon.

  A ref that cannot be followed (a lexicon the entries table does not hold,
  a def the named document does not have) or that closes a cycle is degraded,
  not failed: the ref becomes an `"unknown"` node, which maps to Peri's
  `:any` and leaves that subtree unchecked. One broken cross-reference
  degrades its own subtree instead of failing the whole load.

  Union members keep their refs as keys under `"variants"` (the ref spelled
  as the lexicon wrote it), each mapped to the resolved member definition.
  A member whose ref cannot be followed contributes no variant. Object
  members are annotated with a `"$type"` constant so a Peri `:oneof` can
  discriminate them: on the wire, the `$type` of a union member names it
  with the full ref, so a member pulled in through a local `"#name"` ref is
  annotated with `"doc-id#name"`.
  """

  @type entries :: %{String.t() => document()}
  @type document :: map()
  @type definition :: map()

  @doc """
  Resolves one def of a document against the entries table.

  Returns the resolved definition JSON, or `{:error, {:unknown_def, name}}`
  when the document has no such def.
  """
  @spec resolve_def(document(), String.t(), entries()) :: {:ok, definition()} | {:error, {:unknown_def, String.t()}}
  def resolve_def(%{"defs" => defs} = document, def_name, entries) when is_map(defs) do
    case Map.fetch(defs, def_name) do
      {:ok, def} -> {:ok, resolve(def, document, entries)}
      :error -> {:error, {:unknown_def, def_name}}
    end
  end

  def resolve_def(_document, def_name, _entries), do: {:error, {:unknown_def, def_name}}

  @doc """
  Resolves a definition node against the entries table, starting a fresh
  cycle-tracking set.
  """
  @spec resolve(definition(), document(), entries()) :: definition()
  def resolve(node, document, entries), do: do_resolve(node, document, %{}, entries)

  @doc """
  Pins a union member or record definition to the `$type` it carries on the
  wire: adds a `"$type"` constant property and marks it required.

  Non-object nodes (a token or string def pulled into a union) carry no
  `$type` and pass through unchanged.
  """
  @spec annotate_type(definition(), String.t()) :: definition()
  def annotate_type(%{"type" => "object"} = node, type_id) when is_binary(type_id) do
    node
    |> Map.update("properties", %{"$type" => const(type_id)}, &Map.put(&1, "$type", const(type_id)))
    |> Map.update("required", ["$type"], fn required -> Enum.uniq(["$type" | required]) end)
  end

  def annotate_type(node, _type_id), do: node

  # Refs are pointers, and following them here rather than inside the mapper
  # is what keeps the JSON-to-Peri translation pure: it takes already-inlined
  # JSON and reads no entries table.
  defp do_resolve(%{"type" => "ref", "ref" => ref}, document, seen, entries) when is_binary(ref) do
    case lookup(ref, document, seen, entries) do
      {nil, _document} -> %{"type" => "unknown"}
      {target, target_document} -> do_resolve(target, target_document, Map.put(seen, ref, true), entries)
    end
  end

  # A union keeps its own shape and gains a resolved definition per member
  # ref, keyed by the ref as the lexicon wrote it. The mapper needs the ref
  # spelled that way to pin the member's `$type` literal.
  #
  # A ref is followed with itself added to `seen`, so a union whose members
  # point back at the document holding it terminates instead of resolving
  # forever.
  defp do_resolve(%{"type" => "union"} = node, document, seen, entries) do
    variants =
      [Map.get(node, "ref") | Map.get(node, "refs", [])]
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(fn ref ->
        case lookup(ref, document, seen, entries) do
          {nil, _document} ->
            []

          {target, target_document} ->
            member = do_resolve(target, target_document, Map.put(seen, ref, true), entries)
            [{ref, annotate_type(member, expand_ref(ref, target_document))}]
        end
      end)

    node
    |> Map.put("variants", Map.new(variants))
    |> Map.drop(["refs", "ref"])
  end

  # A record definition wraps its schema in a "record" body; a ref to a
  # record resolves through the body.
  defp do_resolve(%{"type" => "record", "record" => body} = node, document, seen, entries) do
    Map.put(node, "record", do_resolve(body, document, seen, entries))
  end

  defp do_resolve(%{"properties" => properties} = node, document, seen, entries) when is_map(properties) do
    Map.put(
      node,
      "properties",
      Map.new(properties, fn {key, child} ->
        {key, do_resolve(child, document, seen, entries)}
      end)
    )
  end

  defp do_resolve(%{"items" => items} = node, document, seen, entries) when is_map(items),
    do: Map.put(node, "items", do_resolve(items, document, seen, entries))

  defp do_resolve(%{"items" => items} = node, document, seen, entries) when is_list(items),
    do: Map.put(node, "items", Enum.map(items, &do_resolve(&1, document, seen, entries)))

  # Anything else has nothing inside it to follow.
  defp do_resolve(node, _document, _seen, _entries), do: node

  # Each answer carries the document it came from, because that is the
  # document a "#def" inside it has to be looked up in.
  #
  # A ref already being followed is left alone, so two lexicons referring to
  # each other terminate instead of resolving forever: stopping costs one
  # unchecked subtree rather than a hung load.
  #
  # `seen` is a plain map rather than a MapSet: it crosses every do_resolve
  # clause, and MapSet's opaque type is what dialyzer refuses to follow there.
  defp lookup(ref, document, seen, entries) do
    if Map.has_key?(seen, ref) do
      {nil, document}
    else
      foreign(ref, document, entries)
    end
  end

  defp foreign("#" <> name, document, _entries), do: {get_in(document, ["defs", name]), document}

  defp foreign(ref, _document, entries) do
    case String.split(ref, "#", parts: 2) do
      [nsid] -> def_of(entries, nsid, "main")
      [nsid, name] -> def_of(entries, nsid, name)
    end
  end

  # Read from the entries being resolved rather than from any loaded index,
  # so resolution is a function of one generation of the documents.
  defp def_of(entries, nsid, def_name) do
    case Map.fetch(entries, nsid) do
      {:ok, document} -> {get_in(document, ["defs", def_name]), document}
      :error -> {nil, nil}
    end
  end

  # On the wire, a union member's `$type` is its full ref. A member named by
  # a local "#name" ref carries the id of the document defining it.
  defp expand_ref("#" <> _name = ref, document), do: document_id(document) <> ref
  defp expand_ref(ref, _document), do: ref

  defp document_id(%{"id" => id}) when is_binary(id), do: id
  defp document_id(_), do: ""

  defp const(value), do: %{"type" => "string", "const" => value}
end
