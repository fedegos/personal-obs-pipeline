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

ActiveRecord::Schema[8.1].define(version: 2026_01_11_011027) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
end
