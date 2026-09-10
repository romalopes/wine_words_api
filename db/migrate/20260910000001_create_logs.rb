class CreateLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :logs do |t|
      t.string :description, null: false
      t.references :user, null: true, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :method
      t.string :path
      t.integer :status
      t.string :request_id
      t.string :ip_address
      t.text :user_agent

      t.timestamps
    end

    add_index :logs, :created_at
    add_index :logs, :action
    add_index :logs, :request_id
    add_index :logs, :status
    add_index :logs, :method

    create_table :log_objects do |t|
      t.references :log, null: false, foreign_key: true, index: { name: "index_log_objects_on_log_id" }
      t.string :object_type, null: false
      t.bigint :object_id, null: false
      t.string :object_label

      t.timestamps
    end

    add_index :log_objects, [:object_type, :object_id]
  end
end
