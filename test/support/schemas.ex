defmodule EctoGraf.Schemas.User do
  use Ecto.Schema

  schema "user" do
    field :name, :string
  end
end

defmodule EctoGraf.Schemas.Post do
  use Ecto.Schema
  alias EctoGraf.Schemas.User
  alias EctoGraf.Schemas.Tag

  schema "post" do
    field :title, :string
    belongs_to :author, User

    many_to_many :tags, Tag, join_through: "posts_tags"
  end
end

defmodule EctoGraf.Schemas.Comment do
  use Ecto.Schema
  alias EctoGraf.Schemas.Post

  schema "comment" do
    field :body, :string
    belongs_to :post, Post
    belongs_to :parent, __MODULE__
    belongs_to :circular, Circular
  end
end

defmodule EctoGraf.Schemas.CommentEdit do
  use Ecto.Schema
  alias EctoGraf.Schemas.Comment

  schema "comment_edit" do
    field :diff, :string
    belongs_to :comment, Comment

    has_one :post, through: [:comment, :post]
  end
end

defmodule EctoGraf.Schemas.Tag do
  use Ecto.Schema
  alias EctoGraf.Schemas.Post

  schema "tag" do
    field :name, :string

    many_to_many :posts, Post, join_through: "post_tag"
  end
end

defmodule EctoGraf.Schemas.PostTag do
  use Ecto.Schema
  alias EctoGraf.Schemas.Post
  alias EctoGraf.Schemas.Tag

  @primary_key false
  schema "post_tag" do
    belongs_to :post, Post, primary_key: true
    belongs_to :tag, Tag, primary_key: true
  end
end

defmodule EctoGraf.Schemas.ModerationFlag do
  use Ecto.Schema
  alias EctoGraf.Schemas.Post
  alias EctoGraf.Schemas.Comment

  # belongs_to & has_one through
  schema "moderation_flag" do
    belongs_to :post, Post
    belongs_to :comment, Comment

    has_one :comment_post, through: [:comment, :post]
  end
end

defmodule EctoGraf.Schemas.CommentPair do
  use Ecto.Schema
  alias EctoGraf.Schemas.Comment

  # belongs_to & has_one through
  schema "comment_pair" do
    belongs_to :comment_a, Comment
    belongs_to :comment_b, Comment

    has_one :post_a, through: [:comment_a, :post]
    has_one :post_b, through: [:comment_b, :post]
  end
end

defmodule EctoGraf.Schemas.Circular do
  use Ecto.Schema
  alias EctoGraf.Schemas.CommentEdit

  # to check circular reference error
  schema "circular" do
    belongs_to :edit, CommentEdit

    has_one :post, through: [:edit, :post]
  end
end
