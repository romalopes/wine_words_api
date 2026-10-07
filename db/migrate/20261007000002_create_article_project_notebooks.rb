class CreateArticleProjectNotebooks < ActiveRecord::Migration[8.1]
  def change
    create_table :article_project_notebooks do |t|
      t.references :article_project_vintage, null: false, foreign_key: true
      t.string :title, null: false
      t.text :content
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :article_project_notebooks,
              [:article_project_vintage_id, :position],
              name: "index_article_project_notebooks_on_vintage_and_position"
  end
end