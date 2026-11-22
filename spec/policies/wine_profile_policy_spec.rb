require "rails_helper"

# Regression: WineProfile mutations were open to any authenticated user
# (security audit issue #23, High). Writes now require a wine manager.
RSpec.describe WineProfilePolicy, type: :model do
  let(:record) { WineProfile.new }

  describe "as a wine manager" do
    subject(:policy) { described_class.new(instance_double(User, wine_manager?: true), record) }

    it { expect(policy.index?).to be(true) }
    it { expect(policy.show?).to be(true) }
    it { expect(policy.create?).to be(true) }
    it { expect(policy.update?).to be(true) }
    it { expect(policy.destroy?).to be(true) }
  end

  describe "as a non-manager" do
    subject(:policy) { described_class.new(instance_double(User, wine_manager?: false), record) }

    it { expect(policy.index?).to be(true) }
    it { expect(policy.show?).to be(true) }
    it { expect(policy.create?).to be(false) }
    it { expect(policy.update?).to be(false) }
    it { expect(policy.destroy?).to be(false) }
  end

  describe "as an anonymous visitor" do
    subject(:policy) { described_class.new(nil, record) }

    it { expect(policy.index?).to be(true) }
    it { expect(policy.show?).to be(true) }
    it { expect(policy.create?).to be_falsey }
    it { expect(policy.update?).to be_falsey }
    it { expect(policy.destroy?).to be_falsey }
  end
end
