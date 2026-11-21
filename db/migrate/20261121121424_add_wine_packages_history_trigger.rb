class AddWinePackagesHistoryTrigger < ActiveRecord::Migration[8.1]
  def up
    execute <<-SQL
      CREATE OR REPLACE FUNCTION audit_wine_packages()
      RETURNS TRIGGER LANGUAGE plpgsql AS $$
      DECLARE
        v_user_id BIGINT;
      BEGIN
        v_user_id := current_setting('audit.changed_by_id', true)::BIGINT;

        IF TG_OP = 'INSERT' THEN
          INSERT INTO wine_packages_histories (
            wine_package_id, status, source, producer_id, reviewer_id, expected_at,
            announced_at, arrived_at, review_deadline, reviewed_at, notes,
            tracking_carrier, tracking_number, tracking_url, tracking_status,
            tracking_status_updated_at, estimated_delivery_at, delivered_at,
            contact_snapshot, created_by_id, submitter_id, accepted_by_id,
            rejected_by_id, shipping_override_by_id, shipping_override_at,
            producer_reference, producer_notes, shipping_notes, rejection_reason,
            submitted_at, requested_at,
            valid_from, operation, changed_by_id, created_at, updated_at
          ) VALUES (
            NEW.id, NEW.status, NEW.source, NEW.producer_id, NEW.reviewer_id,
            NEW.expected_at, NEW.announced_at, NEW.arrived_at, NEW.review_deadline,
            NEW.reviewed_at, NEW.notes, NEW.tracking_carrier, NEW.tracking_number,
            NEW.tracking_url, NEW.tracking_status, NEW.tracking_status_updated_at,
            NEW.estimated_delivery_at, NEW.delivered_at, NEW.contact_snapshot,
            NEW.created_by_id, NEW.submitter_id, NEW.accepted_by_id,
            NEW.rejected_by_id, NEW.shipping_override_by_id, NEW.shipping_override_at,
            NEW.producer_reference, NEW.producer_notes, NEW.shipping_notes,
            NEW.rejection_reason, NEW.submitted_at, NEW.requested_at,
            now(), 'I', v_user_id, NEW.created_at, NEW.updated_at
          );
          RETURN NEW;

        ELSIF TG_OP = 'UPDATE' THEN
          UPDATE wine_packages_histories
          SET valid_to = now()
          WHERE wine_package_id = OLD.id AND valid_to IS NULL;

          INSERT INTO wine_packages_histories (
            wine_package_id, status, source, producer_id, reviewer_id, expected_at,
            announced_at, arrived_at, review_deadline, reviewed_at, notes,
            tracking_carrier, tracking_number, tracking_url, tracking_status,
            tracking_status_updated_at, estimated_delivery_at, delivered_at,
            contact_snapshot, created_by_id, submitter_id, accepted_by_id,
            rejected_by_id, shipping_override_by_id, shipping_override_at,
            producer_reference, producer_notes, shipping_notes, rejection_reason,
            submitted_at, requested_at,
            valid_from, operation, changed_by_id, created_at, updated_at
          ) VALUES (
            NEW.id, NEW.status, NEW.source, NEW.producer_id, NEW.reviewer_id,
            NEW.expected_at, NEW.announced_at, NEW.arrived_at, NEW.review_deadline,
            NEW.reviewed_at, NEW.notes, NEW.tracking_carrier, NEW.tracking_number,
            NEW.tracking_url, NEW.tracking_status, NEW.tracking_status_updated_at,
            NEW.estimated_delivery_at, NEW.delivered_at, NEW.contact_snapshot,
            NEW.created_by_id, NEW.submitter_id, NEW.accepted_by_id,
            NEW.rejected_by_id, NEW.shipping_override_by_id, NEW.shipping_override_at,
            NEW.producer_reference, NEW.producer_notes, NEW.shipping_notes,
            NEW.rejection_reason, NEW.submitted_at, NEW.requested_at,
            now(), 'U', v_user_id, NEW.created_at, NEW.updated_at
          );
          RETURN NEW;

        ELSIF TG_OP = 'DELETE' THEN
          UPDATE wine_packages_histories
          SET valid_to = now()
          WHERE wine_package_id = OLD.id AND valid_to IS NULL;

          INSERT INTO wine_packages_histories (
            wine_package_id, status, source, producer_id, reviewer_id, expected_at,
            announced_at, arrived_at, review_deadline, reviewed_at, notes,
            tracking_carrier, tracking_number, tracking_url, tracking_status,
            tracking_status_updated_at, estimated_delivery_at, delivered_at,
            contact_snapshot, created_by_id, submitter_id, accepted_by_id,
            rejected_by_id, shipping_override_by_id, shipping_override_at,
            producer_reference, producer_notes, shipping_notes, rejection_reason,
            submitted_at, requested_at,
            valid_from, operation, changed_by_id, created_at, updated_at
          ) VALUES (
            OLD.id, OLD.status, OLD.source, OLD.producer_id, OLD.reviewer_id,
            OLD.expected_at, OLD.announced_at, OLD.arrived_at, OLD.review_deadline,
            OLD.reviewed_at, OLD.notes, OLD.tracking_carrier, OLD.tracking_number,
            OLD.tracking_url, OLD.tracking_status, OLD.tracking_status_updated_at,
            OLD.estimated_delivery_at, OLD.delivered_at, OLD.contact_snapshot,
            OLD.created_by_id, OLD.submitter_id, OLD.accepted_by_id,
            OLD.rejected_by_id, OLD.shipping_override_by_id, OLD.shipping_override_at,
            OLD.producer_reference, OLD.producer_notes, OLD.shipping_notes,
            OLD.rejection_reason, OLD.submitted_at, OLD.requested_at,
            now(), 'D', v_user_id, OLD.created_at, OLD.updated_at
          );
          RETURN OLD;
        END IF;
        RETURN NULL;
      END;
      $$;
    SQL

execute <<-SQL
      DROP TRIGGER IF EXISTS wine_packages_audit_trigger ON wine_packages;
      DROP TRIGGER IF EXISTS wine_packages_audit_trigger_delete ON wine_packages;
      CREATE TRIGGER wine_packages_audit_trigger
      AFTER INSERT OR UPDATE ON wine_packages
      FOR EACH ROW EXECUTE FUNCTION audit_wine_packages();
      CREATE TRIGGER wine_packages_audit_trigger_delete
      BEFORE DELETE ON wine_packages
      FOR EACH ROW EXECUTE FUNCTION audit_wine_packages();
    SQL
  end

  def down
    execute <<-SQL
      DROP TRIGGER IF EXISTS wine_packages_audit_trigger ON wine_packages;
      DROP TRIGGER IF EXISTS wine_packages_audit_trigger_delete ON wine_packages;
      DROP FUNCTION IF EXISTS audit_wine_packages();
    SQL
  end
end