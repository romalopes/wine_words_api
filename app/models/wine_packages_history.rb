class WinePackagesHistory < ApplicationRecord
  self.table_name = 'wine_packages_histories'
  belongs_to :wine_package, foreign_key: :wine_package_id
  belongs_to :changed_by, class_name: 'User', foreign_key: :changed_by_id, optional: true
end