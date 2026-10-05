class CreateArticleProjectVintages < ActiveRecord::Migration[8.1]
  def change
    create_table :article_project_vintages do |t|
      t.references :article_project, null: false, foreign_key: true
      t.references :vintage, null: false, foreign_key: true
      t.boolean :requested, null: false, default: false
      t.boolean :received, null: false, default: false
      t.boolean :selected, null: false, default: false
      t.boolean :tasted, null: false, default: false
      t.date :date_received
      t.string :bottle_condition, null: false, default: "not_assessed"
      t.text :notes
      t.timestamps
    end

    add_index :article_project_vintages, [:article_project_id, :vintage_id], unique: true
  end
end