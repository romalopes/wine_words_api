class BackfillGuestRole < ActiveRecord::Migration[7.1]
  # Give every existing user with no roles the default "Guest" role.
  def up
    guest = Role.find_or_create_by!(name: "Guest")

    User.find_each do |user|
      next if user.roles.exists?

      UserRole.create_or_find_by!(user: user, role: guest)
    end
  end

  def down
    guest = Role.find_by(name: "Guest")
    return unless guest

    UserRole.where(role: guest).delete_all
  end
end