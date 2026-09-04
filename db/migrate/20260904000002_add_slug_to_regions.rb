class AddSlugToRegions < ActiveRecord::Migration[7.1]
  def up
    add_column :regions, :slug, :string
    add_index :regions, :slug, unique: true

    Region.reset_column_information
    used = {}
    Region.find_each do |region|
      base = region.name.to_s.parameterize.presence || "region"
      candidate = base
      i = 2
      while used[candidate] || Region.where(slug: candidate).where.not(id: region.id).exists?
        candidate = "#{base}-#{i}"
        i += 1
      end
      used[candidate] = true
      region.update_columns(slug: candidate)
    end

    change_column_null :regions, :slug, false
  end

  def down
    remove_column :regions, :slug
  end
end