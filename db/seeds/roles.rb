# db/seeds/roles.rb
#
# Seeds the Role records that back the `Role` enum in app/models/role.rb:
# Admin, Editor, Reviewer, Reader, Guest.
# Loaded from db/seeds.rb (or run directly: bin/rails runner db/seeds/roles.rb).
#
# Idempotent: find_or_create_by! on name (backed by the unique index
# index_roles_on_name), so re-running never duplicates rows.
#
# Note: the development database contains a leftover "Super User" row. It is
# deliberately NOT seeded here: it is not part of the Role enum, and reading
# it through ActiveRecord raises ArgumentError. See WINE_WORDS_README.md
# ("Seeded roles: Admin, Editor, Reviewer, Reader, Guest. There is no
# 'Super User'."). Delete the stray row from the database instead.

# Insertion order matches the current primary keys in the development
# database so a fresh database (after destroy_all + reset_pk_sequences)
# reproduces the same id layout.
ROLE_NAMES = %w[
  Guest
  Reader
  Reviewer
  Editor
  Admin
].freeze

Role.transaction do
  ROLE_NAMES.each do |name|
    role = Role.find_or_create_by!(name: name)
    # The enum reader casts to the key (e.g. "guest"); the raw attribute
    # shows the stored human-readable value (e.g. "Guest").
    puts "- Seeded role: #{role.name_before_type_cast} (id #{role.id})"
  end
end

puts "Done. Seeded #{ROLE_NAMES.size} roles (#{Role.count} roles in database)."
