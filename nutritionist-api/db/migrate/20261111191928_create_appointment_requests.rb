class CreateAppointmentRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :appointment_requests do |t|
      t.references :nutritionist, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.references :guest, null: false, foreign_key: true
      t.datetime :scheduled_at, null: false
      t.datetime :ends_at, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :answered_at

      t.timestamps
    end

    add_check_constraint :appointment_requests, "ends_at > scheduled_at", name: "ends_after_start"
    add_check_constraint :appointment_requests, "status IN ('pending','accepted','rejected')", name: "valid_status"

    add_index :appointment_requests, :guest_id, unique: true,
              where: "status = 'pending'", name: "one_pending_per_guest"
    add_index :appointment_requests, [:nutritionist_id, :status]

    add_exclusion_constraint :appointment_requests,
      "nutritionist_id WITH =, tstzrange(scheduled_at, ends_at) WITH &&",
      using: :gist, where: "status = 'accepted'", name: "no_overlapping_accepted"

    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE appointment_requests
            ADD CONSTRAINT fk_service_matches_nutritionist
            FOREIGN KEY (service_id, nutritionist_id) REFERENCES services (id, nutritionist_id);
        SQL
      end
      dir.down { execute "ALTER TABLE appointment_requests DROP CONSTRAINT fk_service_matches_nutritionist" }
    end
  end
end
