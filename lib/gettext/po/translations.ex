defmodule Gettext.PO.Translations do
  @moduledoc false

  alias Gettext.PO
  alias Gettext.PO.Translation
  alias Gettext.PO.PluralTranslation

  defmacrop is_translation(module) do
    quote do
      unquote(module) in [Translation, PluralTranslation]
    end
  end

  @doc """
  Tells whether a translation was manually entered or generated by Gettext.

  As of now, a translation is considered autogenerated if it has the "elixir-format" flag.

  ## Examples

      iex> t = %Gettext.PO.Translation{msgid: "foo", flags: MapSet.new(["elixir-format"])}
      iex> Gettext.PO.Translations.autogenerated?(t)
      true

      iex> t = %Gettext.PO.Translation{msgid: "foo"}
      iex> Gettext.PO.Translations.autogenerated?(t)
      false

  """
  @spec autogenerated?(PO.translation()) :: boolean
  def autogenerated?(%module{flags: flags} = _translation) when is_translation(module) do
    MapSet.member?(flags, "elixir-format")
  end

  @doc """
  Tells whether a translation is protected from purging.

  A translation that is protected from purging will never be removed by Gettext.
  Which translations are proteced can be configured using Mix.

  ## Example

      iex> protected_pattern = ~r{^web/static/}
      iex> t = %Gettext.PO.Translation{msgid: "Hello world!", references: [{"web/static/js/app.js", 42}]}
      iex> Gettext.PO.Translations.protected?(t, protected_pattern)
      true

  """
  @spec protected?(PO.translation(), Regex.t()) :: boolean
  def protected?(_t, nil), do: false

  def protected?(%module{references: []}, _pattern) when is_translation(module), do: false

  def protected?(%module{references: refs}, pattern) when is_translation(module),
    do: Enum.any?(refs, fn {path, _} -> Regex.match?(pattern, path) end)

  @doc """
  Tells whether two translations are the same translation according to their
  `msgid`.

  This function returns `true` if `translation1` and `translation2` are the same
  translation, where "the same" means they have the same `msgid` or the same
  `msgid` and `msgid_plural`.

  ## Examples

      iex> t1 = %Gettext.PO.Translation{msgid: "foo", references: [{"foo.ex", 1}]}
      iex> t2 = %Gettext.PO.Translation{msgid: "foo", comments: ["# hey"]}
      iex> Gettext.PO.Translations.same?(t1, t2)
      true

  """
  @spec same?(PO.translation(), PO.translation()) :: boolean
  def same?(translation1, translation2) do
    key(translation1) == key(translation2)
  end

  @doc """
  Returns a "key" that can be used to identify a translation.

  This function returns a "key" that can be used to uniquely identify a
  translation assuming that no "same" translations exist; for what "same"
  means, look at the documentation for `same?/2`.

  The purpose of this function is to be used in situations where we'd like to
  group or sort translations but where we don't need the whole structs.

  ## Examples

      iex> t = %Gettext.PO.Translation{msgid: "foo"}
      iex> Gettext.PO.Translations.key(t)
      {nil, "foo"}

      iex> t = %Gettext.PO.PluralTranslation{msgid: "foo", msgid_plural: "foos"}
      iex> Gettext.PO.Translations.key(t)
      {nil, {"foo", "foos"}}

      iex> t = %Gettext.PO.PluralTranslation{msgctxt: "bar", msgid: "foo", msgid_plural: "foos"}
      iex> Gettext.PO.Translations.key(t)
      {"bar", {"foo", "foos"}}
  """
  @spec key(PO.translation()) :: {binary | nil, binary | {binary, binary}}
  def key(%{msgctxt: msgctxt} = translation), do: {IO.iodata_to_binary(msgctxt), id_key(translation)}

  defp id_key(%Translation{msgid: msgid}),
    do: IO.iodata_to_binary(msgid)

  defp id_key(%PluralTranslation{msgid: msgid, msgid_plural: msgid_plural}),
    do: {IO.iodata_to_binary(msgid), IO.iodata_to_binary(msgid_plural)}

  @doc """
  Finds a given translation in a list of translations.

  Equality between translations is checked using `same?/2`.
  """
  @spec find([PO.translation()], PO.translation()) :: PO.translation() | nil
  def find(translations, %module{} = target)
      when is_list(translations) and is_translation(module) do
    Enum.find(translations, &same?(&1, target))
  end

  @doc """
  Marks the given translation as "fuzzy".

  This function just adds the `"fuzzy"` flag to the `:flags` field of the given
  translation.
  """
  @spec mark_as_fuzzy(PO.translation()) :: PO.translation()
  def mark_as_fuzzy(%module{flags: flags} = t) when is_translation(module) do
    %{t | flags: MapSet.put(flags, "fuzzy")}
  end
end
