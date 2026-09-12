require "rails_helper"

# Unit specs for the polymorphic join model between Log and the audited object.
# LogObject records the type/id/label snapshot at the moment the audit event
# occurred, so deleted objects can still be labelled in reports.
RSpec.describe LogObject, type: :model do
  let(:log) { Log.create!(description: "test", action: "create") }

  describe "validations" do
    it "requires object_type" do
      obj = log.log_objects.build(object_id: 1)
      expect(obj).not_to be_valid
      expect(obj.errors[:object_type]).to be_present
    end

    it "requires object_id" do
      obj = log.log_objects.build(object_type: "Wine")
      expect(obj).not_to be_valid
      expect(obj.errors[:object_id]).to be_present
    end

    it "accepts a complete record" do
      obj = log.log_objects.build(
        object_type: "Wine",
        object_id: 42,
        object_label: "Penfolds Grange"
      )
      expect(obj).to be_valid
    end
  end

  describe "associations" do
    it "belongs to a log" do
      obj = log.log_objects.create!(
        object_type: "Wine",
        object_id: 1,
        object_label: "test"
      )
      expect(obj.log).to eq(log)
    end

    it "belongs to a polymorphic object (when the record still exists)" do
      producer = Producer.create!(
        name: "Test Winery",
        country: Country.create!(name: "Australia")
      )
      obj = log.log_objects.create!(
        object: producer,
        object_type: "Producer",
        object_id: producer.id,
        object_label: producer.name
      )
      expect(obj.object).to eq(producer)
    end

    it "can reference an object that has been deleted (optional association)" do
      # Polymorphic belongs_to is optional, so a LogObject can survive even
      # when the referenced record no longer exists.
      obj = log.log_objects.create!(
        object_type: "Producer",
        object_id: 99_999,
        object_label: "Deleted Winery"
      )
      expect(obj).to be_persisted
      expect(obj.object).to be_nil
    end
  end
end
