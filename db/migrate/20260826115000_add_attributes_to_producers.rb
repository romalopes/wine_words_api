class AddAttributesToProducers < ActiveRecord::Migration[7.1]
  def up
    change_table :producers do |t|
      t.string :website
      t.text :description
      t.string :instagram
      t.string :facebook
      t.integer :producer_type, default: 0, null: false
    end

    # Existing producers need a valid, unique email (now mandatory) and the
    # winery type (set by the column default).
    Producer.find_each do |producer|
      producer.update_column(:email, "producer-#{producer.slug}-#{SecureRandom.hex(4)}@example.com")
    end
  end

  def down
    remove_columns :producers, :website, :description, :instagram, :facebook, :producer_type
  end
end