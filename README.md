# EctoGraf

[![Build Status](https://github.com/grantwest/ecto_graf/actions/workflows/ci.yml/badge.svg)](https://github.com/grantwest/ecto_graf/actions/workflows/ci.yml)
[![Version](https://img.shields.io/hexpm/v/ecto_graf.svg)](https://hex.pm/packages/ecto_graf)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ecto_graf/)
[![Download](https://img.shields.io/hexpm/dt/ecto_graf.svg)](https://hex.pm/packages/ecto_graf)
[![License](https://img.shields.io/badge/License-0BSD-blue.svg)](https://opensource.org/licenses/0bsd)
[![Last Updated](https://img.shields.io/github/last-commit/grantwest/ecto_graf.svg)](https://github.com/grantwest/ecto_graf/commits/master)

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
