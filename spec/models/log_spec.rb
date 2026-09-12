require "rails_helper"

# Unit specs for the append-only audit Log model.
#
# Log records are the backbone of the admin audit trail. They are written by
# LogService (never directly by controllers) and are immutable once created.
RSpec.describe Log, type: :model do
  let(:user) do
    User.create!(
      user_name: "Tester",
      email: "tester@example.com",
      password: "password123"
    )
  end

  describe "validations" do
    it "requires a description" do
      log = Log.new(action: "create")
      expect(log).not_to be_valid
      expect(log.errors[:description]).to be_present
    end

    it "requires an action" do
      log = Log.new(description: "Updated something")
      expect(log).not_to be_valid
      expect(log.errors[:action]).to be_present
    end

    it "accepts a complete record" do
      log = Log.new(
        description: "User updated wine",
        action: "update",
        user: user
      )
      expect(log).to be_valid
    end
  end

  describe "associations" do
    it "belongs to a user (optional)" do
      log = Log.create!(description: "system event", action: "create")
      expect(log.user).to be_nil
    end

    it "can belong to a user when one is provided" do
      log = Log.create!(description: "user event", action: "create", user: user)
      expect(log.user).to eq(user)
    end

    it "has many log_objects" do
      log = Log.create!(description: "with objects", action: "create")
      log.log_objects.create!(
        object_type: "Wine",
        object_id: 1,
        object_label: "Test Wine"
      )
      expect(log.log_objects.size).to eq(1)
    end
  end

  describe "#object_labels" do
    it "returns an empty array when there are no log_objects" do
      log = Log.create!(description: "no objects", action: "create")
      expect(log.object_labels).to be_empty
    end

    it "returns a label snapshot for each attached object" do
      wine = Wine.create!(
        name: "Château Margaux 2010",
        color: "Red",
        prompt: "x"
      )
      log = Log.create!(description: "event", action: "create")
      log.log_objects.create!(
        object: wine,
        object_type: "Wine",
        object_id: wine.id,
        object_label: wine.name
      )
      labels = log.object_labels
      expect(labels.size).to eq(1)
      expect(labels.first[:type]).to eq("Wine")
      expect(labels.first[:id]).to eq(wine.id)
      expect(labels.first[:label]).to eq("Château Margaux 2010")
    end

    it "falls back to the live record label when no snapshot was stored" do
      wine = Wine.create!(
        name: "Live Label Wine",
        color: "Red",
        prompt: "x"
      )
      log = Log.create!(description: "no snapshot", action: "create")
      log.log_objects.create!(
        object: wine,
        object_type: "Wine",
        object_id: wine.id,
        object_label: nil # no snapshot label stored
      )
      expect(log.object_labels.first[:label]).to eq("Live Label Wine")
    end

    it "sets alive to true when the referenced object still exists" do
      wine = Wine.create!(
        name: "Existing Wine",
        color: "Red",
        prompt: "x"
      )
      log = Log.create!(description: "alive test", action: "create")
      log.log_objects.create!(
        object: wine,
        object_type: "Wine",
        object_id: wine.id,
        object_label: wine.name
      )
      expect(log.object_labels.first[:alive]).to eq(true)
    end

    it "sets alive to false when the referenced object has been deleted" do
      wine = Wine.create!(
        name: "To Be Deleted",
        color: "Red",
        prompt: "x"
      )
      log = Log.create!(description: "deleted object", action: "create")
      log.log_objects.create!(
        object: wine,
        object_type: "Wine",
        object_id: wine.id,
        object_label: wine.name
      )

      # Simulate deletion of the wine after the log was written.
      wine.destroy!

      labels = log.reload.object_labels
      expect(labels.first[:alive]).to eq(false)
      # The label snapshot is still available even though the record is gone.
      expect(labels.first[:label]).to eq("To Be Deleted")
    end
  end

  describe "attr_readonly fields" do
    it "does not update description when set to readonly" do
      log = Log.create!(
        description: "original",
        action: "create",
        user: user
      )
      log.update!(description: "tampered")
      expect(log.reload.description).to eq("original")
    end

    it "does not update action when set to readonly" do
      log = Log.create!(
        description: "event",
        action: "create",
        user: user
      )
      log.update!(action: "destroy")
      expect(log.reload.action).to eq("create")
    end

    it "does not update method when set to readonly" do
      log = Log.create!(
        description: "event",
        action: "create",
        method: "GET",
        user: user
      )
      log.update!(method: "POST")
      expect(log.reload.method).to eq("GET")
    end

    it "does not update path when set to readonly" do
      log = Log.create!(
        description: "event",
        action: "create",
        path: "/wines",
        user: user
      )
      log.update!(path: "/wines/1")
      expect(log.reload.path).to eq("/wines")
    end

    it "does not update status when set to readonly" do
      log = Log.create!(
        description: "event",
        action: "create",
        status: 200,
        user: user
      )
      log.update!(status: 500)
      expect(log.reload.status).to eq(200)
    end

    it "does not update request_id when set to readonly" do
      log = Log.create!(
        description: "event",
        action: "create",
        request_id: "req-123",
        user: user
      )
      log.update!(request_id: "req-456")
      expect(log.reload.request_id).to eq("req-123")
    end

    it "does not update ip_address when set to readonly" do
      log = Log.create!(
        description: "event",
        action: "create",
        ip_address: "192.168.1.1",
        user: user
      )
      log.update!(ip_address: "10.0.0.1")
      expect(log.reload.ip_address).to eq("192.168.1.1")
    end

    it "does not update user_agent when set to readonly" do
      log = Log.create!(
        description: "event",
        action: "create",
        user_agent: "Mozilla/5.0",
        user: user
      )
      log.update!(user_agent: "Chrome/1.0")
      expect(log.reload.user_agent).to eq("Mozilla/5.0")
    end
  end

  describe "ordering" do
    it "sorts by created_at desc, then id desc as a tiebreaker" do
      log1 = Log.create!(description: "first", action: "create", user: user)
      log2 = Log.create!(description: "second", action: "create", user: user)
      log3 = Log.create!(description: "third", action: "create", user: user)

      ordered = Log.order(created_at: :desc, id: :desc).to_a
      expect(ordered).to eq([log3, log2, log1])
    end
  end
end

