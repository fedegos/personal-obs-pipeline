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

ActiveRecord::Schema[8.1].define(version: 2026_01_21_164932) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "category_rules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "parent_id"
    t.string "pattern"
    t.integer "priority"
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_category_rules_on_parent_id"
  end

  create_table "source_files", force: :cascade do |t|
    t.string "bank"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.jsonb "extra_params"
    t.string "file_key"
    t.datetime "processed_at"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["file_key"], name: "index_source_files_on_file_key"
  end

  create_table "transactions", force: :cascade do |t|
    t.boolean "aprobado", default: false, null: false
    t.string "categoria"
    t.datetime "created_at", null: false
    t.string "detalles"
    t.string "event_id", null: false
    t.datetime "fecha", null: false
    t.string "moneda"
    t.decimal "monto", precision: 15, scale: 2, null: false
    t.string "red"
    t.string "sentimiento"
    t.string "sub_categoria"
    t.datetime "updated_at", null: false
    t.index ["aprobado"], name: "index_transactions_on_aprobado"
    t.index ["event_id"], name: "index_transactions_on_event_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end
end
