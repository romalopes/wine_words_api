class AddLikesAndLikesCount < ActiveRecord::Migration[8.1]
  def change
    create_table :likes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :likeable, polymorphic: true, null: false

      t.timestamps
    end

    add_index :likes,
              [:user_id, :likeable_type, :likeable_id],
              unique: true,
              name: "index_likes_on_user_and_likeable"
    # NOTE: t.references :likeable, polymorphic: true above already creates
    # index_likes_on_likeable (likeable_type, likeable_id), so no extra
    # lookup index is needed here.

    add_column :wines, :likes_count, :integer, null: false, default: 0
    add_column :reviews, :likes_count, :integer, null: false, default: 0
    add_column :articles, :likes_count, :integer, null: false, default: 0
  end
end
