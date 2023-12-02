defmodule EctoClone do
  @moduledoc """
  Documentation for `EctoClone`.
  """

  import Ecto.Query
  alias Ecto.Association.BelongsTo
  alias Ecto.Association.HasThrough

  @max_parameters 65535

  @type target() :: struct()
  @type related_schema_with_options() :: module() | list()

  @doc """
  Deep clones a target record.

  `target` is the record to be cloned.

  `repo` is the ecto repo to operate on, the current implementation supports only a single repo.

  `new_attrs` is a map that will override values on the clone of the target.

  `related_schemas_with_options` is the list of schemas to clone in relation to the target.
  The order of schemas does not matter, EctoClone determines clone order by associations.
  See examples for setting options per schema. Suppored options include:

  `map` - a function that takes the source row fields as a map and returns the cloned row fields

  `where` - a function that appends a where clause to the sql query and thus filters which rows should be cloned


  ## Examples

  To clone a post with it's comments:
      post = Repo.insert!(%Post{title: "hello"})
      Repo.insert!(%Comment{body: "p", post_id: post.id})
      {:ok, clone_id} = EctoClone.clone(post, Repo, %{title: "New Title"}, [Comment])

  To clone a post with it's tags, comments, comment edits:
      EctoClone.clone(post, Repo, %{}, [
        PostTag,
        Comment,
        CommentEdit
      ])

  Options on schemas allow chaning values of cloned records:
      EctoClone.clone(post, Repo, %{}, [
        PostTag,
        [Comment, map: fn comment -> Map.put(comment, :likes, 0) end],
        CommentEdit
      ])

  The where option allows selective cloning at the schema level:
      EctoClone.clone(post, Repo, %{}, [
        PostTag,
        [Comment, where: fn query -> where(query, [comment], comment.likes >= 0) end],
        CommentEdit
      ])

  If you use the ecto timestamps and want to set inserted_at on all of your cloned records, you can use the map option globally:
      now = your_get_timestamp_function()
      EctoClone.clone(
        post,
        Repo,
        %{},
        [PostTag, Comment, CommentEdit],
        map: fn r -> Map.put(r, :inserted_at, now) end
      )

  ## Association Requirements

  Each related schema being cloned must have either a belongs_to or has_one through association to the target.

  A Comment can be cloned along with a Post because it has `belongs_to :post, Post`

  A CommentEdit can be cloned with a Post because it has `belongs_to :comment, Comment` and `has_one :post, through: [:comment, :post]`

  It is possible to have multiple possible relations to the target. A schema can have multiple has_one through:
      schema "comment_pair" do
        belongs_to :comment_a, Comment
        belongs_to :comment_b, Comment

        has_one :post_a, through: [:comment_a, :post]
        has_one :post_b, through: [:comment_b, :post]
      end

  Or a schema can have both a belongs_to AND has_one through:
      schema "moderation_flag" do
        belongs_to :post, Post
        belongs_to :comment, Comment

        has_one :comment_post, through: [:comment, :post]
      end

  These examples, while contrived, show that a record can have multple potential paths to being related to the target.
  Every possible path is exhausted when determing if a record is related to the clone target.
  """
  @spec clone(target(), Ecto.Repo.t(), map(), [related_schema_with_options()]) ::
          {:ok, any()} | {:error, binary()}
  def clone(target, repo, new_attrs, related_schemas_with_options, global_opts \\ []) do
    %target_schema{} = target

    schema_options =
      Enum.map(related_schemas_with_options, fn
        schema when is_atom(schema) -> {schema, global_opts}
        [schema | schema_opts] when is_atom(schema) -> {schema, global_opts ++ schema_opts}
        other -> raise "invalid schema #{inspect(other)}"
      end)
      |> Map.new()

    target_opts =
      [
        map: fn t -> Map.merge(t, new_attrs) end
      ] ++ global_opts

    schema_options = Map.put(schema_options, target_schema, target_opts)
    schemas = Map.keys(schema_options)
    ordered_schemas = clone_order(schemas)

    repo.transaction(fn repo ->
      state = %{
        repo: repo,
        schemas: schemas,
        schema_opts: schema_options
      }

      final_state =
        Enum.reduce(ordered_schemas, state, fn schema, state ->
          clone_rows_of_schema(schema, target, state)
        end)

      case final_state[{:id_map, target_schema}][target.id] do
        nil -> repo.rollback("target not found")
        clone_id -> clone_id
      end
    end)
  end

  defp clone_rows_of_schema(schema, target, state) do
    clonable_fields = clonable_fields(schema)
    chunk_size = div(@max_parameters, Enum.count(clonable_fields))
    remappable_assocs = remappable_references(schema, state.schemas)

    id_mapping =
      stream_rows(schema, target, state)
      |> Stream.chunk_every(chunk_size)
      |> Stream.flat_map(fn rows ->
        new_rows =
          Enum.map(rows, &clone_row(&1, schema, clonable_fields, remappable_assocs, state))

        count = Enum.count(new_rows)
        {^count, inserted} = state.repo.insert_all(schema, new_rows, returning: true)
        Enum.zip(rows, inserted)
      end)
      |> Stream.map(fn {old_row, new_row} -> {Map.get(old_row, :id), Map.get(new_row, :id)} end)
      |> Map.new()

    state = Map.put(state, {:id_map, schema}, id_mapping)

    self_associations = self_associations(schema)

    unless self_associations == [] do
      self_assoc_fields = Enum.map(self_associations, & &1.owner_key)
      primary_key_fields = schema.__schema__(:primary_key)
      fields_to_take = primary_key_fields ++ self_assoc_fields
      chunk_size = div(@max_parameters, Enum.count(fields_to_take))

      from(row in schema, select: row, where: row.id in ^Map.values(id_mapping))
      |> state.repo.stream()
      |> Stream.chunk_every(chunk_size)
      |> Stream.each(fn rows ->
        remapped_rows =
          rows
          |> Enum.map(&remap_associations(&1, self_associations, state))
          |> Enum.map(&Map.take(&1, primary_key_fields ++ self_assoc_fields))

        {_count, nil} =
          state.repo.insert_all(schema, remapped_rows,
            returning: false,
            on_conflict: {:replace, self_assoc_fields},
            conflict_target: primary_key_fields
          )
      end)
      |> Stream.run()
    end

    state
  end

  defp clone_row(row, schema, clonable_fields, remappable_assocs, state) do
    row
    |> apply_map_functions(schema, state)
    |> remap_associations(remappable_assocs, state)
    |> Map.take(clonable_fields)
  end

  defp apply_map_functions(row, schema, state) do
    state.schema_opts[schema]
    |> Keyword.get_values(:map)
    |> Enum.reduce(row, fn map_fn, row -> map_fn.(row) end)
  end

  defp remap_associations(row, associations, state) do
    Enum.reduce(associations, row, fn %BelongsTo{} = belongs_to, row ->
      Map.update(row, belongs_to.owner_key, nil, fn
        nil ->
          nil

        old_id ->
          state
          |> Map.fetch!({:id_map, belongs_to.related})
          |> Map.fetch!(old_id)
      end)
    end)
  end

  defp remappable_references(schema, schemas_to_clone) do
    schemas = MapSet.new(schemas_to_clone)

    belongs_to_associations(schema)
    |> Enum.filter(&MapSet.member?(schemas, &1.related))
    |> Enum.filter(&(&1.related != schema))
  end

  defp clonable_fields(schema) do
    schema.__schema__(:fields)
    |> MapSet.new()
    |> MapSet.difference(MapSet.new(autogenerated_id_fields(schema)))
    |> Enum.to_list()
  end

  defp autogenerated_id_fields(schema) do
    case schema.__schema__(:autogenerate_id) do
      nil -> []
      {field, field, field} -> [field]
    end
  end

  defp stream_rows(schema, target, state) do
    from(row in schema, select: row)
    |> order_by(^schema.__schema__(:primary_key))
    |> apply_where_opts(schema, state)
    |> join_to_target(schema, target.__struct__, target)
    |> state.repo.stream()
  end

  defp apply_where_opts(query, schema, state) do
    state.schema_opts[schema]
    |> Keyword.get_values(:where)
    |> Enum.reduce(query, fn where, query -> where.(query) end)
  end

  defp join_to_target(query, target_schema, target_schema, target) do
    where(query, id: ^target.id)
  end

  defp join_to_target(query, schema, target_schema, target) do
    associations_to_target(schema, target_schema)
    |> Enum.with_index()
    |> Enum.reduce(query, fn {assoc, i}, query ->
      query = join(query, :left, [schema, ...], t in assoc(schema, ^assoc.field))

      case i do
        0 -> where(query, [..., t], not is_nil(t) and t.id == ^target.id)
        _ -> or_where(query, [..., t], not is_nil(t) and t.id == ^target.id)
      end
    end)
  end

  defp associations(schema) do
    schema.__schema__(:associations)
    |> Enum.map(&schema.__schema__(:association, &1))
  end

  defp belongs_to_associations(schema) do
    schema
    |> associations()
    |> Enum.filter(&match?(%BelongsTo{}, &1))
  end

  defp self_associations(schema) do
    belongs_to_associations(schema)
    |> Enum.filter(&(&1.related == schema))
  end

  defp associations_to_target(schema, target_schema) do
    associations(schema)
    |> Enum.filter(fn
      %BelongsTo{related: ^target_schema} -> true
      %HasThrough{cardinality: :one} = assoc -> related_schema(assoc) == target_schema
      _ -> false
    end)
    |> Enum.to_list()
    |> case do
      [] -> raise "#{schema} has no belongs_to or has_one association to #{target_schema}"
      assocs -> assocs
    end
  end

  defp related_schema(%HasThrough{through: [local_field, remote_field], owner: schema}) do
    %{related: related_schema} = schema.__schema__(:association, local_field)

    case related_schema.__schema__(:association, remote_field) do
      %BelongsTo{related: schema} -> schema
      %HasThrough{} = has_through -> related_schema(has_through)
    end
  end

  defp clone_order(schemas) do
    schemas_set = MapSet.new(schemas)

    schema_parents =
      Map.new(schemas, fn s ->
        {s,
         associations(s)
         |> Enum.filter(&match?(%BelongsTo{}, &1))
         |> Enum.reject(fn belongs_to -> belongs_to.owner == belongs_to.related end)
         |> Enum.filter(&MapSet.member?(schemas_set, &1.related))}
      end)

    schemas
    |> Enum.map(fn schema -> {schema, height(schema, schema_parents)} end)
    |> Enum.sort_by(fn {_schema, height} -> height end)
    |> Enum.map(fn {schema, _height} -> schema end)
  end

  defp height(schema, schema_parents) do
    case schema_parents[schema] do
      [] ->
        0

      parent_assocs ->
        Enum.map(parent_assocs, &height(&1.related, schema_parents))
        |> Enum.max()
        |> Kernel.+(1)
    end
  end
end
