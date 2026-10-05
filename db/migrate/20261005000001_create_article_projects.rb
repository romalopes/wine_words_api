class CreateArticleProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :article_projects do |t|
      t.string :name, null: false
      t.string :publication
      t.string :editor_name
      t.string :editor_email
      t.string :project_status, null: false, default: "initiated"
      t.string :drafting_status, null: false, default: "not_initiated"
      t.date :deadline
      t.integer :target_word_count
      t.text :description
      t.references :article, foreign_key: { on_delete: :nullify }, index: { unique: true }
      t.references :created_by, null: false, foreign_key: { to_table: :users, on_delete: :nullify }
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :article_projects, :project_status
    add_index :article_projects, :deadline
  end
end