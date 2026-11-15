# Accent-insensitive search ("joao" finds "João") without SQL functions: each searchable
# text gets a normalized copy (no accents, lowercase), kept up to date by the model.
# The trigram indexes move to these columns, which is where the search now looks.
class AddSearchColumnsToNutritionistsAndServices < ActiveRecord::Migration[7.1]
  # Minimal models, so the migration does not depend on the application models.
  class MigrationNutritionist < ActiveRecord::Base
    self.table_name = "nutritionists"
  end

  class MigrationService < ActiveRecord::Base
    self.table_name = "services"
  end

  def up
    add_column :nutritionists, :name_search, :string
    add_column :services, :description_search, :string

    MigrationNutritionist.find_each { |n| n.update_columns(name_search: SearchText.normalize(n.name)) }
    MigrationService.find_each { |s| s.update_columns(description_search: SearchText.normalize(s.description)) }

    change_column_null :nutritionists, :name_search, false
    change_column_null :services, :description_search, false

    remove_index :nutritionists, name: "index_nutritionists_on_name"
    remove_index :services, name: "index_services_on_description"
    add_index :nutritionists, :name_search, using: :gin, opclass: :gin_trgm_ops
    add_index :services, :description_search, using: :gin, opclass: :gin_trgm_ops
  end

  def down
    remove_index :nutritionists, :name_search
    remove_index :services, :description_search
    add_index :nutritionists, :name, using: :gin, opclass: :gin_trgm_ops
    add_index :services, :description, using: :gin, opclass: :gin_trgm_ops

    remove_column :nutritionists, :name_search
    remove_column :services, :description_search
  end
end
