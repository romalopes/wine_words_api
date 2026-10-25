class CreateFollows < ActiveRecord::Migration[8.1]
  def change
    create_table :follows do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :followable_type, null: false
      t.bigint :followable_id, null: false
      t.timestamps
    end

    add_index :follows, [:user_id, :followable_type, :followable_id],
              unique: true, name: :index_follows_on_user_and_followable
    add_index :follows, [:followable_type, :followable_id, :user_id],
              name: :index_follows_on_followable_and_user

    # Check constraint for allowed followable types (reversible — raw execute
    # inside `change` is not).
    reversible do |direction|
      direction.up do
        execute <<-SQL
          ALTER TABLE follows
          ADD CONSTRAINT follows_followable_type_check
          CHECK (followable_type IN ('Producer', 'Wine', 'Review', 'Article'));
        SQL
      end
      direction.down do
        execute "ALTER TABLE follows DROP CONSTRAINT IF EXISTS follows_followable_type_check;"
      end
    end
  end
end
