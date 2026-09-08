class CreateSolidQueueProcessAndRecurringTables < ActiveRecord::Migration[8.1]
  def change
    create_table :solid_queue_processes do |t|
      t.string :kind, null: false
      t.datetime :last_heartbeat_at, null: false
      t.bigint :supervisor_id
      t.integer :pid, null: false
      t.string :hostname
      t.text :metadata
      t.datetime :created_at, null: false
      t.string :name, null: false

      t.index :last_heartbeat_at, name: "index_solid_queue_processes_on_last_heartbeat_at"
      t.index [:name, :supervisor_id],
              name: "index_solid_queue_processes_on_name_and_supervisor_id",
              unique: true
      t.index :supervisor_id, name: "index_solid_queue_processes_on_supervisor_id"
    end

    create_table :solid_queue_pauses do |t|
      t.string :queue_name, null: false
      t.datetime :created_at, null: false

      t.index :queue_name,
              name: "index_solid_queue_pauses_on_queue_name",
              unique: true
    end

    create_table :solid_queue_recurring_tasks do |t|
      t.string :key, null: false
      t.string :schedule, null: false
      t.string :command, limit: 2048
      t.string :class_name
      t.text :arguments
      t.string :queue_name
      t.integer :priority, default: 0
      t.boolean :static, default: true, null: false
      t.text :description
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index :key, name: "index_solid_queue_recurring_tasks_on_key", unique: true
      t.index :static, name: "index_solid_queue_recurring_tasks_on_static"
    end

    create_table :solid_queue_recurring_executions do |t|
      t.bigint :job_id, null: false
      t.string :task_key, null: false
      t.datetime :run_at, null: false
      t.datetime :created_at, null: false

      t.index :job_id,
              name: "index_solid_queue_recurring_executions_on_job_id",
              unique: true
      t.index [:task_key, :run_at],
              name: "index_solid_queue_recurring_executions_on_task_key_and_run_at",
              unique: true
    end

    create_table :solid_queue_semaphores do |t|
      t.string :key, null: false
      t.integer :value, default: 1, null: false
      t.datetime :expires_at, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index :expires_at, name: "index_solid_queue_semaphores_on_expires_at"
      t.index [:key, :value], name: "index_solid_queue_semaphores_on_key_and_value"
      t.index :key, name: "index_solid_queue_semaphores_on_key", unique: true
    end

    add_foreign_key :solid_queue_recurring_executions, :solid_queue_jobs,
                    column: :job_id, on_delete: :cascade
  end
end
