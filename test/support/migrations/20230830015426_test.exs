defmodule EctoGraf.Repo.Migrations.Test do
  use Ecto.Migration

  def change do
    create table("user") do
      add(:name, :string)
    end

    create table("post") do
      add(:title, :string)
      add(:author_id, references(:user))
    end

    create table("comment") do
      add(:body, :string)
      add(:likes, :integer)
      add(:post_id, references(:post))
      add(:parent_id, references(:comment))
    end

    create table("comment_edit") do
      add(:diff, :string)
      add(:comment_id, references(:comment))
    end

    create table("tag") do
      add(:name, :string)
    end

    create table("post_tag", primary_key: false) do
      add(:post_id, references(:post), primary_key: true)
      add(:tag_id, references(:tag), primary_key: true)
    end

    create table("moderation_flag") do
      add(:reason, :string)
      add(:post_id, references(:post))
      add(:comment_id, references(:comment))
    end

    create table("comment_pair") do
      add(:comment_a_id, references(:comment))
      add(:comment_b_id, references(:comment))
    end

    create table("circular") do
      add(:edit_id, references(:comment_edit))
    end

    alter table("comment") do
      add(:circular_id, references(:circular))
    end
  end
end
