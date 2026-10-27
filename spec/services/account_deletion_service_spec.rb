require "rails_helper"

RSpec.describe AccountDeletionService, type: :service do
  # Register the Stripe provider before validation (lazy autoloading — see
  # spec/models/billing_spec.rb).
  before { Billing::Providers::Stripe }

  def create_user(attrs = {})
    User.create!({ email: "user-#{SecureRandom.hex(4)}@example.com",
                   password: "password123" }.merge(attrs))
  end

  def with_role(user, role_name)
    role = Role.find_or_create_by!(name: role_name)
    user.roles << role unless user.roles.exists?(id: role.id)
    user
  end

  let(:actor)  { with_role(create_user, "Admin") }
  let(:target) { create_user }

  describe ".soft_delete" do
    it "marks the user as deleted" do
      result = described_class.soft_delete(target, actor: actor)

      expect(result.success?).to be true
      expect(target.reload.deleted?).to be true
      expect(target.reload.deleted_at).to be_present
    end

    it "schedules the 30-day hard-delete job" do
      expect do
        described_class.soft_delete(target, actor: actor)
      end.to have_enqueued_job(DeleteUserJob).with(target.id)
    end

    it "returns failure for an already soft-deleted user" do
      target.update!(deleted_at: Time.current)

      result = described_class.soft_delete(target, actor: actor)

      expect(result.success?).to be false
    end
  end

  describe ".reactivate" do
    it "clears deleted_at" do
      target.update!(deleted_at: Time.current)

      result = described_class.reactivate(target, actor: actor)

      expect(result.success?).to be true
      expect(target.reload.deleted_at).to be_nil
    end

    it "returns failure for a user that is not deleted" do
      result = described_class.reactivate(target, actor: actor)

      expect(result.success?).to be false
    end
  end

  describe ".hard_delete" do
    context "when the feature flag is disabled (default)" do
      it "refuses with hard_delete_disabled" do
        allow(AppSetting).to receive(:hard_delete_enabled?).and_return(false)

        result = described_class.hard_delete(target, actor: actor)

        expect(result.success?).to be false
        expect(result.error).to eq("hard_delete_disabled")
        expect(User.exists?(target.id)).to be true
      end
    end

    context "when the feature flag is enabled" do
      before { allow(AppSetting).to receive(:hard_delete_enabled?).and_return(true) }

      it "destroys the user and its account when no blockers exist" do
        result = described_class.hard_delete(target, actor: actor)

        expect(result.success?).to be true
        expect(User.find_by(id: target.id)).to be_nil
        expect(Account.find_by(user_id: target.id)).to be_nil
      end

      it "returns blocked with reasons when a blocking dependency exists" do
        BillingCustomer.create!(user: target, provider: "stripe", provider_customer_id: "cus_#{SecureRandom.hex(4)}")

        result = described_class.hard_delete(target, actor: actor)

        expect(result.success?).to be false
        expect(result.error).to eq("blocked")
        expect(result.blocking_reasons.map { |r| r[:code] }).to include("billing_customers")
        expect(User.exists?(target.id)).to be true
      end

      it "blocks when the target is the last active administrator" do
        non_admin_actor = create_user
        admin_target = with_role(create_user, "Admin")

        result = described_class.hard_delete(admin_target, actor: non_admin_actor)

        expect(result.success?).to be false
        expect(result.blocking_reasons.map { |r| r[:code] }).to include("last_admin")
        expect(User.exists?(admin_target.id)).to be true
      end
    end
  end
end
