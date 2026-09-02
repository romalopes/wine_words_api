class RenameVintagePriceToPriceCents < ActiveRecord::Migration[8.1]
  def up
    add_column :vintages, :price_cents, :integer
    # Convert existing decimal dollar values to integer cents (45.55 -> 4555).
    execute <<~SQL
      UPDATE vintages
      SET price_cents = ROUND(price * 100)
      WHERE price IS NOT NULL
    SQL
    remove_column :vintages, :price
  end

  def down
    add_column :vintages, :price, :decimal, precision: 10, scale: 2
    execute <<~SQL
      UPDATE vintages
      SET price = price_cents / 100.0
      WHERE price_cents IS NOT NULL
    SQL
    remove_column :vintages, :price_cents
  end
end