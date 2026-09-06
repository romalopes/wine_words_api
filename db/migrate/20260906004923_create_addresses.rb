class CreateAddresses < ActiveRecord::Migration[8.1]
  def up
    create_table :addresses do |t|
      t.string :street_address
      t.string :city
      t.string :state
      t.string :postal_code
      t.bigint :producer_id, null: false
      t.bigint :country_id, null: false

      t.timestamps
    end

    add_index :addresses, :producer_id, unique: true
    add_foreign_key :addresses, :producers
    add_foreign_key :addresses, :countries

    # Copy existing producer address data into the new table. A producer has
    # at most one address; the country is seeded from the producer's own
    # country (Producer#set_default_country guarantees one exists).
    Producer.find_each do |producer|
      next if [producer.address, producer.city, producer.state, producer.postal_code].all?(&:blank?)

      Address.create!(
        producer: producer,
        street_address: producer.address,
        city: producer.city,
        state: producer.state,
        postal_code: producer.postal_code,
        country: producer.country
      )
    end

    remove_columns :producers, :address, :city, :state, :postal_code
  end

  def down
    # Restore the columns and copy data back before dropping the table.
    add_column :producers, :address, :string
    add_column :producers, :city, :string
    add_column :producers, :state, :string
    add_column :producers, :postal_code, :string

    Address.find_each do |address|
      producer = address.producer
      producer.update_columns(
        address: address.street_address,
        city: address.city,
        state: address.state,
        postal_code: address.postal_code
      )
    end

    drop_table :addresses
  end
end
