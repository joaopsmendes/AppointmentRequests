class CreateNutritionists < ActiveRecord::Migration[7.1]
  def change
    create_table :nutritionists do |t|
      t.string :name, null: false
      t.string :license_number, null: false
      t.string :photo_url

      t.timestamps
    end

    add_index :nutritionists, :name, using: :gin, opclass: :gin_trgm_ops

    add_unique_constraint :nutritionists, :license_number, name: "unique_license_number"
  end
end
