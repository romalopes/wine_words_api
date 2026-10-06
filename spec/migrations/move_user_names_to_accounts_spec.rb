require "rails_helper"
require Rails.root.join("db/migrate/20261006000001_move_user_names_to_accounts")

RSpec.describe MoveUserNamesToAccounts do
  it "backfills every missing account, preserves real profile names, and removes unique handles" do
    connection = ActiveRecord::Base.connection
    connection.add_column :users, :user_name, :string
    connection.add_index :users, :user_name, unique: true

    missing = User.create!(email: "missing-profile@example.com", password: "password123")
    named = User.create!(email: "named-profile@example.com", password: "password123", first_name: "Real", last_name: "Person")
    partial = User.create!(email: "partial-profile@example.com", password: "password123", last_name: "Known")
    single = User.create!(email: "single-profile@example.com", password: "password123")
    unknown = User.create!(email: "unknown-profile@example.com", password: "password123")
    Account.where(user_id: [missing.id, unknown.id]).delete_all

    { missing => "  Legacy   Family Name  ", named => "oldhandle", partial => "otherhandle", single => "single" }.each do |user, name|
      connection.execute("UPDATE users SET user_name = #{connection.quote(name)} WHERE id = #{user.id}")
    end
    migration = described_class.new
    migration.suppress_messages { migration.up }

    expect(User.where.missing(:account)).to be_empty
    expect(missing.reload.account.attributes.slice("first_name", "last_name")).to eq("first_name" => "Legacy", "last_name" => "Family Name")
    expect(named.reload.display_name).to eq("Real Person")
    expect(partial.reload.account.first_name).to be_nil
    expect(partial.account.last_name).to eq("Known")
    expect(single.reload.account.first_name).to eq("single")
    expect(single.account.last_name).to be_nil
    expect(unknown.reload.account.first_name).to be_nil
    expect(connection.column_exists?(:users, :user_name)).to be(false)
    expect(connection.indexes(:users).any? { |index| index.columns == ["email"] && index.unique }).to be(true)
  ensure
    User.reset_column_information
    Account.reset_column_information
  end
end
