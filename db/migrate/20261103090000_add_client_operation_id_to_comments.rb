class AddClientOperationIdToComments < ActiveRecord::Migration[8.1]
  def change
    add_column :comments, :client_operation_id, :string
    add_index :comments,
              [ :user_id, :client_operation_id ],
              unique: true,
              where: "client_operation_id IS NOT NULL",
              name: "index_comments_on_user_and_client_operation"
  end
end
