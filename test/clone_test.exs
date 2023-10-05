defmodule EctoGraf.CloneTest do
  use ExUnit.Case, async: true
  import Ecto.Query
  alias EctoGraf.Repo
  alias EctoGraf.Schemas.Comment
  alias EctoGraf.Schemas.CommentEdit
  alias EctoGraf.Schemas.CommentPair
  alias EctoGraf.Schemas.Post
  alias EctoGraf.Schemas.PostTag
  alias EctoGraf.Schemas.Tag
  alias EctoGraf.Schemas.User

  test "clone simplest post" do
    post = Repo.insert!(%Post{title: "hello"})
    before = all_entires()

    {:ok, clone_id} = EctoGraf.clone(post, Repo, %{}, [])

    assert %{
             posts: [%Post{id: ^clone_id, title: "hello", author_id: nil}],
             comments: [],
             edits: [],
             tags: [],
             post_tags: [],
             comment_pairs: []
           } = diff(before, all_entires())
  end

  test "cloned post keeps reference to uncloned user" do
    user = Repo.insert!(%User{name: "alice"})
    post = Repo.insert!(%Post{title: "hello", author_id: user.id})
    before = all_entires()

    {:ok, clone_id} = EctoGraf.clone(post, Repo, %{}, [])

    user_id = user.id

    assert %{
             posts: [%Post{id: ^clone_id, title: "hello", author_id: ^user_id}],
             comments: [],
             edits: [],
             tags: [],
             post_tags: [],
             comment_pairs: []
           } = diff(before, all_entires())
  end

  test "clone simplest post and set new attribute" do
    post = Repo.insert!(%Post{title: "hello"})
    before = all_entires()

    {:ok, clone_id} = EctoGraf.clone(post, Repo, %{title: "newtitle"}, [])

    assert %{
             posts: [%Post{id: ^clone_id, title: "newtitle"}],
             comments: [],
             edits: [],
             tags: [],
             post_tags: [],
             comment_pairs: []
           } = diff(before, all_entires())
  end

  test "clone post with child comment" do
    post = Repo.insert!(%Post{title: "hello"})
    Repo.insert!(%Comment{body: "first", post_id: post.id})
    before = all_entires()

    {:ok, clone_id} = EctoGraf.clone(post, Repo, %{}, [Comment])

    assert %{
             posts: [%Post{id: ^clone_id, title: "hello"}],
             comments: [%Comment{body: "first", post_id: ^clone_id}],
             edits: [],
             tags: [],
             post_tags: [],
             comment_pairs: []
           } = diff(before, all_entires())
  end

  test "clone post with nested child comments - self reference" do
    post = Repo.insert!(%Post{title: "hello"})
    comment = Repo.insert!(%Comment{body: "p", post_id: post.id})
    Repo.insert!(%Comment{body: "c", post_id: post.id, parent_id: comment.id})
    before = all_entires()

    {:ok, clone_id} = EctoGraf.clone(post, Repo, %{}, [Comment])

    assert %{
             posts: [%Post{id: ^clone_id, title: "hello"}],
             comments: [
               %Comment{body: "p", post_id: ^clone_id, parent_id: nil, id: parent_id},
               %Comment{body: "c", post_id: ^clone_id, parent_id: parent_id}
             ],
             edits: [],
             tags: [],
             post_tags: [],
             comment_pairs: []
           } = diff(before, all_entires())
  end

  test "clone post with comment edits - has_one post through comment" do
    post = Repo.insert!(%Post{title: "hello"})
    comment = Repo.insert!(%Comment{body: "c", post_id: post.id})
    Repo.insert!(%CommentEdit{diff: "d", comment_id: comment.id})
    before = all_entires()

    {:ok, clone_id} = EctoGraf.clone(post, Repo, %{}, [Comment, CommentEdit])

    assert %{
             posts: [%Post{id: ^clone_id, title: "hello"}],
             comments: [%Comment{id: comment_id, body: "c", post_id: ^clone_id, parent_id: nil}],
             edits: [%CommentEdit{diff: "d", comment_id: comment_id}],
             tags: [],
             post_tags: [],
             comment_pairs: []
           } = diff(before, all_entires())
  end

  test "clone post with tags - many_to_many relationship" do
    post = Repo.insert!(%Post{title: "hello"})
    tag = Repo.insert!(%Tag{name: "t"})
    Repo.insert!(%PostTag{post_id: post.id, tag_id: tag.id})
    before = all_entires()

    {:ok, clone_id} = EctoGraf.clone(post, Repo, %{}, [PostTag])

    tag_id = tag.id

    assert %{
             posts: [%Post{id: ^clone_id, title: "hello"}],
             comments: [],
             edits: [],
             tags: [],
             post_tags: [%PostTag{post_id: ^clone_id, tag_id: ^tag_id}],
             comment_pairs: []
           } = diff(before, all_entires())
  end

  test "clone post with comment pair - multiple has_one through" do
    post = Repo.insert!(%Post{title: "hello"})
    comment_a = Repo.insert!(%Comment{body: "a", post_id: post.id})
    comment_b = Repo.insert!(%Comment{body: "b", post_id: post.id})
    Repo.insert!(%CommentPair{comment_a_id: comment_a.id, comment_b_id: comment_b.id})
    before = all_entires()

    {:ok, clone_id} = EctoGraf.clone(post, Repo, %{}, [Comment, CommentPair])

    assert %{
             posts: [%Post{id: ^clone_id, title: "hello"}],
             comments: [
               %Comment{id: a_id, body: "a", post_id: ^clone_id},
               %Comment{id: b_id, body: "b", post_id: ^clone_id}
             ],
             edits: [],
             tags: [],
             post_tags: [],
             comment_pairs: [%CommentPair{comment_a_id: a_id, comment_b_id: b_id}]
           } = diff(before, all_entires())
  end

  @tag :slow
  test "clone post with extreme number of comments - clone chunks to avoid db limits" do
    post = Repo.insert!(%Post{title: "hello"})
    # this is intended to exceed the postgres max parameters of 65535
    comment_count = 80_000

    Enum.map(1..comment_count, fn ci ->
      %{body: "#{ci}", post_id: post.id}
    end)
    |> Enum.chunk_every(10_000)
    |> Enum.each(fn comments ->
      count = Enum.count(comments)
      {^count, nil} = Repo.insert_all(Comment, comments)
    end)

    {:ok, clone_id} = EctoGraf.clone(post, Repo, %{}, [Comment])

    count = Repo.aggregate(from(c in Comment, where: c.post_id == ^clone_id), :count)
    assert count == comment_count
  end

  test "map option on individual schema" do
    post = Repo.insert!(%Post{title: "hello"})
    Repo.insert!(%Comment{body: "first", post_id: post.id})
    before = all_entires()

    {:ok, clone_id} =
      EctoGraf.clone(post, Repo, %{}, [[Comment, map: fn c -> Map.put(c, :body, "new") end]])

    assert %{
             posts: [%Post{id: ^clone_id, title: "hello"}],
             comments: [%Comment{body: "new", post_id: ^clone_id}],
             edits: [],
             tags: [],
             post_tags: [],
             comment_pairs: []
           } = diff(before, all_entires())
  end

  test "global map option" do
    post = Repo.insert!(%Post{title: "hello"})
    Repo.insert!(%Comment{body: "first", post_id: post.id})
    before = all_entires()

    {:ok, clone_id} =
      EctoGraf.clone(post, Repo, %{}, [Comment], map: fn c -> Map.put(c, :body, "new") end)

    assert %{
             posts: [%Post{id: ^clone_id, title: "hello"}],
             comments: [%Comment{body: "new", post_id: ^clone_id}],
             edits: [],
             tags: [],
             post_tags: [],
             comment_pairs: []
           } = diff(before, all_entires())
  end

  test "combined schema map option and global map option" do
    post = Repo.insert!(%Post{title: "hello"})
    Repo.insert!(%Comment{body: "first", likes: 1, post_id: post.id})
    before = all_entires()

    {:ok, clone_id} =
      EctoGraf.clone(
        post,
        Repo,
        %{},
        [[Comment, map: fn c -> Map.put(c, :likes, -1) end]],
        map: fn c -> Map.put(c, :body, "new") end
      )

    assert %{
             posts: [%Post{id: ^clone_id, title: "hello"}],
             comments: [%Comment{body: "new", likes: -1, post_id: ^clone_id}],
             edits: [],
             tags: [],
             post_tags: [],
             comment_pairs: []
           } = diff(before, all_entires())
  end

  test "schema map option takes precedence over global map option" do
    post = Repo.insert!(%Post{title: "hello"})
    Repo.insert!(%Comment{body: "first", likes: 1, post_id: post.id})
    before = all_entires()

    {:ok, clone_id} =
      EctoGraf.clone(
        post,
        Repo,
        %{},
        [[Comment, map: fn c -> Map.put(c, :body, "schema") end]],
        map: fn c -> Map.put(c, :body, "global") end
      )

    assert %{
             posts: [%Post{id: ^clone_id, title: "hello"}],
             comments: [%Comment{body: "schema", post_id: ^clone_id}],
             edits: [],
             tags: [],
             post_tags: [],
             comment_pairs: []
           } = diff(before, all_entires())
  end

  test "where option" do
    post = Repo.insert!(%Post{title: "hello"})
    Repo.insert!(%Comment{body: "1", post_id: post.id})
    Repo.insert!(%Comment{body: "2", post_id: post.id})
    before = all_entires()

    {:ok, clone_id} =
      EctoGraf.clone(post, Repo, %{}, [[Comment, where: &where(&1, [c], c.body == "1")]])

    assert %{
             posts: [%Post{id: ^clone_id, title: "hello"}],
             comments: [%Comment{body: "1", post_id: ^clone_id}],
             edits: [],
             tags: [],
             post_tags: [],
             comment_pairs: []
           } = diff(before, all_entires())
  end

  test "target not found error" do
    post = %Post{id: -1}
    assert EctoGraf.clone(post, Repo, %{}, []) == {:error, "target not found"}
  end

  test "no association to target error" do
    user = Repo.insert!(%User{name: "alice"})
    post = Repo.insert!(%Post{title: "hello", author_id: user.id})

    assert_raise RuntimeError,
                 "Elixir.EctoGraf.Schemas.User has no belongs_to or has_one association to Elixir.EctoGraf.Schemas.Post",
                 fn ->
                   EctoGraf.clone(post, Repo, %{}, [User])
                 end
  end

  @tag :skip
  test "intermediate schema(s) missing error" do
    post = Repo.insert!(%Post{title: "hello"})
    comment = Repo.insert!(%Comment{body: "c", post_id: post.id})
    Repo.insert!(%CommentEdit{diff: "d", comment_id: comment.id})

    assert_raise RuntimeError,
                 "Elixir.EctoGraf.Schemas.Comment missing from schemas to clone",
                 fn ->
                   EctoGraf.clone(post, Repo, %{}, [CommentEdit])
                 end
  end

  @tag :skip
  test "circular associations error" do
  end

  defp all_entires() do
    %{
      posts: Repo.all(from(x in Post, order_by: x.id)),
      comments: Repo.all(from(x in Comment, order_by: x.id)),
      edits: Repo.all(from(x in CommentEdit, order_by: x.id)),
      tags: Repo.all(from(x in Tag, order_by: x.id)),
      post_tags: Repo.all(from(x in PostTag, order_by: [x.post_id, x.tag_id])),
      comment_pairs: Repo.all(from(x in CommentPair, order_by: x.id))
    }
  end

  defp diff(before, now) do
    Map.merge(before, now, fn _key, before_list, after_list ->
      before_set = MapSet.new(before_list)
      Enum.reject(after_list, &MapSet.member?(before_set, &1))
    end)
  end
end
