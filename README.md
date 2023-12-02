# EctoClone

[![Build Status](https://github.com/grantwest/ecto_clone/actions/workflows/ci.yml/badge.svg)](https://github.com/grantwest/ecto_clone/actions/workflows/ci.yml)
[![Version](https://img.shields.io/hexpm/v/ecto_clone.svg)](https://hex.pm/packages/ecto_clone)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ecto_clone/)
[![Download](https://img.shields.io/hexpm/dt/ecto_clone.svg)](https://hex.pm/packages/ecto_clone)
[![License](https://img.shields.io/badge/License-0BSD-blue.svg)](https://opensource.org/licenses/0bsd)
[![Last Updated](https://img.shields.io/github/last-commit/grantwest/ecto_clone.svg)](https://github.com/grantwest/ecto_clone/commits/master)

Take advantage of Ecto associations to deep clone data in your database.

To clone a post with it's comments and tags:

```elixir
{:ok, cloned_post_id} = EctoClone.clone(%Post{id: 5}, Repo, %{title: "new title"}, [Comment, PostTag])
```

See [clone docs](https://hexdocs.pm/ecto_clone/EctoClone.html#clone/4) for more information and examples.

### Todo

- [ ] error when intermediate schemas are missing
- [ ] support mysql
- [ ] support sqlite
- [ ] clone tables in parallel
- [ ] fix self references in parallel
- [ ] support foreign key != :id
- [ ] error when circular associations
