class AddEditorRole < ActiveRecord::Migration[7.1]
  def up
    Role.find_or_create_by!(name: "Editor")

    change_column_default :producers, :producer_type, 0
    change_column_null :producers, :producer_type, false

    Category.create(name: "Tastings", slug: "tastings") unless Category.find_by(name: "Tastings") # TASTINGS
    Category.create(name: "Australian Icons", slug: "australian-icons") unless Category.find_by(name: "Australian Icons")
    Category.create(name: "Interviews", slug: "interviews") unless Category.find_by(name: "Interviews")
    Category.create(name: "Australian Chardonnay | Best Reviewed", slug: "australian-chardonnay-best-reviewed") unless Category.find_by(name: "Australian Chardonnay | Best Reviewed")
    Category.create(name: "Eno Travel", slug: "eno-travel") unless Category.find_by(name: "Eno Travel")
    Category.create(name: "Regional Tastings", slug: "regional-tastings") unless Category.find_by(name: "Regional Tastings")
    Category.create(name: "Producer Spotlight", slug: "producer-spotlight") unless Category.find_by(name: "Producer Spotlight")
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