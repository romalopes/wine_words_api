class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :user, null: false, foreign_key: true
      # The single polymorphic target: Wine, Review or Article.
      t.references :commentable, polymorphic: true, null: false
      # NULL = top-level comment; otherwise the comment being replied to.
      # Self-referencing so replies stay in the same table (one model, one
      # serializer, one set of endpoints).
      t.references :parent, null: true, foreign_key: { to_table: :comments }
      t.text :body, null: false
      # Soft delete. The row (and therefore its place in the thread) survives so
      # replies keep their context; the API renders it as "[Comment deleted]".
      t.datetime :deleted_at

      t.timestamps
    end

    # t.references :user, :commentable and :parent each create their own index:
    #   index_comments_on_user_id
    #   index_comments_on_commentable (commentable_type, commentable_id)
    #   index_comments_on_parent_id
    # The polymorphic index is the hot path (loading one thread); parent_id is
    # the second (loading the replies of a comment). No further lookup index is
    # needed.
    #
    # NOTE: no `comments_count` counter cache on the commentable for now. The
    # only visible count in the UI is the thread size, which the index endpoint
    # already knows because it loads the comments. A counter cache would also
    # need to be decremented on SOFT delete, which is an easy place to drift.
  end
end