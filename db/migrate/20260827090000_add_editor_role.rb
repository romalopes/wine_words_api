class AddEditorRole < ActiveRecord::Migration[7.1]
  def up
    Role.find_or_create_by!(name: "Editor")
  end

  def down
    editor = Role.find_by(name: "Editor")
    return unless editor

    if UserRole.exists?(role: editor)
      raise "Cannot remove the Editor role while users still hold it."
    end

    editor.destroy!
  end
end