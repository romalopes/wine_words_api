require "rails_helper"

RSpec.describe LogService do
  let(:user) do
    User.create!(user_name: "Audited", email: "audited@example.com", password: "password123")
  end
  let(:producer) { Producer.create!(name: "Penfolds", slug: "penfolds") }

  describe ".log" do
    it "creates a log record with the provided metadata" do
      log = LogService.log(
        description: 'Updated wine "Grange"',
        action: "update",
        user: user,
        method: "PATCH",
        path: "/api/v1/wines/1",
        status: 200,
        request_id: "req-abc",
        ip_address: "127.0.0.1",
        user_agent: "RSpec/1.0"
      )

      expect(log).to be_persisted
      expect(log.description).to eq('Updated wine "Grange"')
      expect(log.action).to eq("update")
      expect(log.user).to eq(user)
      expect(log[:method]).to eq("PATCH")
      expect(log.path).to eq("/api/v1/wines/1")
      expect(log.status).to eq(200)
      expect(log.request_id).to eq("req-abc")
      expect(log.ip_address).to eq("127.0.0.1")
      expect(log.user_agent).to eq("RSpec/1.0")
    end

    it "truncates values longer than the maximum length" do
      log = LogService.log(description: "a" * 3000, action: "b" * 3000, user: user)

      expect(log.description.length).to eq(LogService::MAX_TEXT_LENGTH)
      expect(log.action.length).to eq(LogService::MAX_TEXT_LENGTH)
    end

    it "stores a non-integer status as nil" do
      log = LogService.log(description: "x", action: "create", status: "200")

      expect(log.status).to be_nil
    end

    it "supports anonymous operations (user: nil)" do
      log = LogService.log(description: "System cleanup", action: "cleanup")

      expect(log.user).to be_nil
      expect(log).to be_persisted
    end

    it "attaches ActiveRecord objects with a label" do
      log = LogService.log(
        description: "Updated producer",
        action: "update",
        user: user,
        objects: [producer]
      )

      object = log.log_objects.sole
      expect(object.object_type).to eq("Producer")
      expect(object.object_id).to eq(producer.id)
      expect(object.object_label).to eq("Penfolds")
    end

    it "attaches [type, id, label] triples for objects already deleted at log time" do
      log = LogService.log(
        description: "Deleted producer",
        action: "destroy",
        objects: [["Producer", 424_242, "Old Producer"]]
      )

      object = log.log_objects.sole
      expect(object.object_type).to eq("Producer")
      expect(object.object_id).to eq(424_242)
      expect(object.object_label).to eq("Old Producer")
      expect(log.object_labels.first[:alive]).to be(false)
      expect(log.object_labels.first[:label]).to eq("Old Producer")
    end

    it "skips invalid object entries without losing the log" do
      log = LogService.log(
        description: "Mixed",
        action: "update",
        objects: [nil, "not-a-record", producer]
      )

      expect(log).to be_persisted
      expect(log.log_objects.count).to eq(1)
      expect(log.log_objects.first.object).to eq(producer)
    end

    it "never raises when persistence fails" do
      allow(Rails.logger).to receive(:error)
      allow(Log).to receive(:create!).and_raise(StandardError, "db down")

      expect(LogService.log(description: "x", action: "create")).to be_nil
      expect(Rails.logger).to have_received(:error).with(/\[audit\] failed to write log/)
    end
  end
end