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

ActiveRecord::Schema[8.1].define(version: 2026_04_22_074746) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_clients", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "api_key_digest", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["api_key_digest"], name: "index_api_clients_on_api_key_digest", unique: true
  end

  create_table "api_requests", force: :cascade do |t|
    t.bigint "api_client_id"
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}
    t.string "method", null: false
    t.string "path", null: false
    t.integer "status", null: false
    t.datetime "updated_at", null: false
    t.index ["api_client_id"], name: "index_api_requests_on_api_client_id"
  end

  create_table "assessment_events", force: :cascade do |t|
    t.bigint "assessment_id", null: false
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.jsonb "payload", default: {}
    t.datetime "updated_at", null: false
    t.index ["assessment_id"], name: "index_assessment_events_on_assessment_id"
    t.index ["event_type"], name: "index_assessment_events_on_event_type"
  end

  create_table "assessments", force: :cascade do |t|
    t.datetime "computed_at", null: false
    t.datetime "created_at", null: false
    t.string "decision", null: false
    t.text "explanation"
    t.jsonb "failures"
    t.jsonb "metrics"
    t.bigint "mortgage_application_id", null: false
    t.datetime "updated_at", null: false
    t.integer "version", null: false
    t.index ["mortgage_application_id", "computed_at"], name: "index_assessments_on_mortgage_application_id_and_computed_at"
    t.index ["mortgage_application_id", "version"], name: "index_assessments_on_mortgage_application_id_and_version", unique: true
    t.index ["mortgage_application_id"], name: "index_assessments_on_mortgage_application_id"
  end

  create_table "mortgage_applications", force: :cascade do |t|
    t.decimal "annual_income", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.decimal "deposit", precision: 12, scale: 2
    t.decimal "monthly_expenses", precision: 12, scale: 2
    t.decimal "property_value", precision: 12, scale: 2
    t.uuid "public_id", default: -> { "gen_random_uuid()" }, null: false
    t.string "status", default: "processing", null: false
    t.integer "term_years"
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_mortgage_applications_on_public_id", unique: true
    t.index ["status"], name: "index_mortgage_applications_on_status"
  end

  add_foreign_key "api_requests", "api_clients"
  add_foreign_key "assessment_events", "assessments"
  add_foreign_key "assessments", "mortgage_applications"
end
