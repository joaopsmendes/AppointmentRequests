class CreateServices < ActiveRecord::Migration[7.1]
  def change
    create_table :services do |t|
      t.references :nutritionist, null: false, foreign_key: true
      t.string :description, null: false
      t.integer :price_cents, null: false
      t.integer :duration_minutes, null: false
      t.string :location, null: false

      t.timestamps
    end

    add_check_constraint :services, "price_cents > 0", name: "positive_price"
    add_check_constraint :services, "duration_minutes > 0", name: "positive_duration"

    add_index :services, :description, using: :gin, opclass: :gin_trgm_ops
    add_index :services, [:id, :nutritionist_id], unique: true
  end
end
