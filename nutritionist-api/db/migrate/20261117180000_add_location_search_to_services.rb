# Accent-insensitive location filter ("porto" and "Pórto" find "Porto"), with the same approach
# as name_search and description_search: a normalized copy kept up to date by the model.
class AddLocationSearchToServices < ActiveRecord::Migration[7.1]
  # Minimal model, so the migration does not depend on the application models.
  class MigrationService < ActiveRecord::Base
    self.table_name = "services"
  end

  def up
    add_column :services, :location_search, :string

    MigrationService.find_each { |s| s.update_columns(location_search: SearchText.normalize(s.location)) }

    change_column_null :services, :location_search, false
    add_index :services, :location_search, using: :gin, opclass: :gin_trgm_ops
  end

  def down
    remove_index :services, :location_search
    remove_column :services, :location_search
  end
end
