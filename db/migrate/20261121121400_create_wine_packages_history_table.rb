class CreateWinePackagesHistoryTable < ActiveRecord::Migration[8.1]
  def change
    execute <<-SQL
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_tables WHERE tablename = 'wine_packages_histories'
        ) THEN
          CREATE TABLE wine_packages_histories (
            wine_package_id BIGINT NOT NULL,
            status VARCHAR(32) NOT NULL,
            source VARCHAR(32),
            producer_id BIGINT,
            reviewer_id BIGINT,
            expected_at TIMESTAMP WITHOUT TIME ZONE,
            announced_at TIMESTAMP WITHOUT TIME ZONE,
            arrived_at TIMESTAMP WITHOUT TIME ZONE,
            review_deadline DATE,
            reviewed_at TIMESTAMP WITHOUT TIME ZONE,
            notes TEXT,
            tracking_carrier VARCHAR,
            tracking_number VARCHAR,
            tracking_url VARCHAR,
            tracking_status VARCHAR,
            tracking_status_updated_at TIMESTAMP WITHOUT TIME ZONE,
            estimated_delivery_at TIMESTAMP WITHOUT TIME ZONE,
            delivered_at TIMESTAMP WITHOUT TIME ZONE,
            contact_snapshot JSONB,
            created_by_id BIGINT,
            submitter_id BIGINT,
            accepted_by_id BIGINT,
            rejected_by_id BIGINT,
            shipping_override_by_id BIGINT,
            shipping_override_at TIMESTAMP WITHOUT TIME ZONE,
            producer_reference VARCHAR,
            producer_notes TEXT,
            shipping_notes TEXT,
            rejection_reason VARCHAR,
            submitted_at TIMESTAMP WITHOUT TIME ZONE,
            requested_at TIMESTAMP WITHOUT TIME ZONE,
            valid_from TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
            valid_to TIMESTAMP WITH TIME ZONE,
            operation CHAR(1) NOT NULL,
            changed_by_id BIGINT,
            created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
            updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL
          );

          CREATE INDEX idx_wine_packages_histories_package_id ON wine_packages_histories(wine_package_id);
          CREATE INDEX idx_wine_packages_histories_valid_range ON wine_packages_histories(valid_from, valid_to);
          CREATE INDEX idx_wine_packages_histories_changed_by_id ON wine_packages_histories(changed_by_id);
        END IF;
      END $$;
    SQL
  end
end
