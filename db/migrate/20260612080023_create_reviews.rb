class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.references :vintage, null: false, foreign_key: true
      t.text :comment
      t.decimal :score, precision: 5, scale: 2
      t.string :status, null: false, default: "draft"
      t.datetime :published_at

      t.timestamps
    end
  end
end
