# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_11_17_180000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "citext"
  enable_extension "pg_trgm"
  enable_extension "plpgsql"

  create_table "appointment_requests", force: :cascade do |t|
    t.bigint "nutritionist_id", null: false
    t.bigint "service_id", null: false
    t.bigint "guest_id", null: false
    t.datetime "scheduled_at", null: false
    t.datetime "ends_at", null: false
    t.string "status", default: "pending", null: false
    t.datetime "answered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["guest_id"], name: "index_appointment_requests_on_guest_id"
    t.index ["guest_id"], name: "one_pending_per_guest", unique: true, where: "((status)::text = 'pending'::text)"
    t.index ["nutritionist_id", "status"], name: "index_appointment_requests_on_nutritionist_id_and_status"
    t.index ["nutritionist_id"], name: "index_appointment_requests_on_nutritionist_id"
    t.index ["service_id"], name: "index_appointment_requests_on_service_id"
    t.check_constraint "ends_at > scheduled_at", name: "ends_after_start"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'accepted'::character varying::text, 'rejected'::character varying::text])", name: "valid_status"
    t.exclusion_constraint "nutritionist_id WITH =, tstzrange(scheduled_at, ends_at) WITH &&", where: "(status)::text = 'accepted'::text", using: :gist, name: "no_overlapping_accepted"
  end

  create_table "guests", force: :cascade do |t|
    t.string "name", null: false
    t.citext "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_guests_on_email", unique: true
  end

  create_table "nutritionists", force: :cascade do |t|
    t.string "name", null: false
    t.string "license_number", null: false
    t.string "photo_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name_search", null: false
    t.index ["name_search"], name: "index_nutritionists_on_name_search", opclass: :gin_trgm_ops, using: :gin
    t.unique_constraint ["license_number"], name: "unique_license_number"
  end

  create_table "services", force: :cascade do |t|
    t.bigint "nutritionist_id", null: false
    t.string "description", null: false
    t.integer "price_cents", null: false
    t.integer "duration_minutes", null: false
    t.string "location", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "description_search", null: false
    t.string "location_search", null: false
    t.index ["description_search"], name: "index_services_on_description_search", opclass: :gin_trgm_ops, using: :gin
    t.index ["id", "nutritionist_id"], name: "index_services_on_id_and_nutritionist_id", unique: true
    t.index ["location_search"], name: "index_services_on_location_search", opclass: :gin_trgm_ops, using: :gin
    t.index ["nutritionist_id"], name: "index_services_on_nutritionist_id"
    t.check_constraint "duration_minutes > 0", name: "positive_duration"
    t.check_constraint "price_cents > 0", name: "positive_price"
  end

  add_foreign_key "appointment_requests", "guests"
  add_foreign_key "appointment_requests", "nutritionists"
  add_foreign_key "appointment_requests", "services"
  add_foreign_key "appointment_requests", "services", column: ["service_id", "nutritionist_id"], primary_key: ["id", "nutritionist_id"], name: "fk_service_matches_nutritionist"
  add_foreign_key "services", "nutritionists"
end
