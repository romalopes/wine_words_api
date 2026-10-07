class AddLockVersionToArticleProjectNotebooks < ActiveRecord::Migration[8.1]
  def change
    add_column :article_project_notebooks, :lock_version, :integer, null: false, default: 0
  end
end