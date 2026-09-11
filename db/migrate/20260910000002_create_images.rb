class CreateImages < ActiveRecord::Migration[8.1]
  def change
    create_table :images do |t|
      t.references :imageable, polymorphic: true, null: false, index: false
      t.boolean :primary, null: false, default: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :images, [:imageable_type, :imageable_id]
    # Ordering lookup: imageable + position.
    add_index :images,
              [:imageable_type, :imageable_id, :position],
              name: "index_images_on_imageable_and_position"
  end
end