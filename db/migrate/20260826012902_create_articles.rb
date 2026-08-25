class CreateArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :articles do |t|
      t.string :title, null: false
      t.text :abstract
      t.text :body
      t.string :status, default: "draft", null: false
      t.datetime :published_at
      t.references :user, null: false, foreign_key: true
      t.references :category, foreign_key: true

      t.timestamps
    end
  end
end