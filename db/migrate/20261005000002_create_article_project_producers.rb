class CreateArticleProjectProducers < ActiveRecord::Migration[8.1]
  def change
    create_table :article_project_producers do |t|
      t.references :article_project, null: false, foreign_key: true
      t.references :producer, null: false, foreign_key: true
      t.boolean :contacted, null: false, default: false
      t.boolean :request_confirmed, null: false, default: false
      t.text :notes
      t.timestamps
    end

    add_index :article_project_producers, [:article_project_id, :producer_id], unique: true
  end
end