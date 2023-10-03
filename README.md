# EctoGraf

[![CI](https://github.com/grantwest/ecto_graf/actions/workflows/ci.yml/badge.svg)](https://github.com/grantwest/ecto_graf/actions/workflows/ci.yml)

Take advantage of Ecto associations to deep clone data in your database.

To clone a post with it's comments and tags:

```elixir
{:ok, cloned_post_id} = EctoGraf.clone(%Post{id: 5}, Repo, %{title: "new title"}, [Comment, PostTag])
```

### Todo

- [ ] error when intermediate schemas are missing
- [ ] allow setting inserted_at, updated_at
- [ ] filter with where clause
- [ ] support mysql
- [ ] support sqlite
- [ ] clone tables in parallel
- [ ] fix self references in parallel
- [ ] support foreign key != :id
- [ ] error when circular associations
