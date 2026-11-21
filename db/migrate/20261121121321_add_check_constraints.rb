class AddCheckConstraints < ActiveRecord::Migration[8.1]
  def change
    # Use DO blocks to conditionally add check constraints
    execute <<-SQL
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'wine_packages_status_check'
        ) THEN
          ALTER TABLE wine_packages
          ADD CONSTRAINT wine_packages_status_check
          CHECK (status IN ('draft', 'requested', 'accepted', 'rejected', 'announced', 'in_transit', 'arrived', 'reviewing', 'completed', 'cancelled', 'editorial_pending', 'assessment_in_progress', 'partially_approved', 'approved', 'quoted', 'invoiced', 'paid', 'shipping_pending', 'shipping_released'));
        END IF;
      END $$;
    SQL

    execute <<-SQL
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'wine_package_items_item_status_check'
        ) THEN
          ALTER TABLE wine_package_items
          ADD CONSTRAINT wine_package_items_item_status_check
          CHECK (item_status IN ('pending', 'approved', 'rejected', 'information_requested', 'matched', 'shipped', 'received'));
        END IF;
      END $$;
    SQL

    execute <<-SQL
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'subscription_changes_change_type_check'
        ) THEN
          ALTER TABLE subscription_changes
          ADD CONSTRAINT subscription_changes_change_type_check
          CHECK (change_type IN ('upgrade', 'downgrade', 'same', 'renewal', 'cancellation', 'checkout'));
        END IF;
      END $$;
    SQL

    execute <<-SQL
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'reviews_status_check'
        ) THEN
          ALTER TABLE reviews
          ADD CONSTRAINT reviews_status_check
          CHECK (status IN ('draft', 'published', 'archived'));
        END IF;
      END $$;
    SQL

    execute <<-SQL
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'articles_status_check'
        ) THEN
          ALTER TABLE articles
          ADD CONSTRAINT articles_status_check
          CHECK (status IN ('draft', 'published', 'archived'));
        END IF;
      END $$;
    SQL

    execute <<-SQL
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'vintages_price_cents_nonnegative'
        ) THEN
          ALTER TABLE vintages
          ADD CONSTRAINT vintages_price_cents_nonnegative
          CHECK (price_cents IS NULL OR price_cents >= 0);
        END IF;
      END $$;
    SQL

    execute <<-SQL
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'wine_package_items_quantity_positive'
        ) THEN
          ALTER TABLE wine_package_items
          ADD CONSTRAINT wine_package_items_quantity_positive
          CHECK (quantity > 0);
        END IF;
      END $$;
    SQL

    execute <<-SQL
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'subscription_billing_prices_amount_cents_nonnegative'
        ) THEN
          ALTER TABLE subscription_billing_prices
          ADD CONSTRAINT subscription_billing_prices_amount_cents_nonnegative
          CHECK (amount_cents IS NULL OR amount_cents >= 0);
        END IF;
      END $$;
    SQL

    execute <<-SQL
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'subscription_changes_amount_cents_nonnegative'
        ) THEN
          ALTER TABLE subscription_changes
          ADD CONSTRAINT subscription_changes_amount_cents_nonnegative
          CHECK (amount_cents IS NULL OR amount_cents >= 0);
        END IF;
      END $$;
    SQL
  end
end
