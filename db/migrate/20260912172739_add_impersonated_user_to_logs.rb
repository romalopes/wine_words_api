class AddImpersonatedUserToLogs < ActiveRecord::Migration[8.1]
  def change
    add_reference :logs, :impersonated_user, null: true, foreign_key: { to_table: :users },
                 index: { name: "index_logs_on_impersonated_user_id" }
  end
end
