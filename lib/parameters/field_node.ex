defmodule Parameters.FieldNode do
  defstruct [
    :id,
    :type,
    :fields,
    options: []
  ]

  def parse({:__block__, _metadata, ast}), do: parse(ast)
  def parse(ast) when is_list(ast), do: Enum.map(ast, &parse/1)

  def parse({name, _metadata, args}) do
    case args do
      [field, type, [do: ast]] ->
        opts = [required: name == :requires]
        fields = parse(ast)
        fields = if is_list(fields), do: fields, else: [fields]
        struct(__MODULE__, id: field, type: type, options: opts, fields: fields)

      [field, type, opts] ->
        opts = Keyword.put(opts, :required, name == :requires)
        struct(__MODULE__, id: field, type: type, options: opts)

      [field, type] ->
        opts = [required: name == :requires]
        struct(__MODULE__, id: field, type: type, options: opts)
    end
  end
end
