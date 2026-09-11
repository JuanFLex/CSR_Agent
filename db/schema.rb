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

ActiveRecord::Schema[8.0].define(version: 2026_09_11_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "csr_escalations", force: :cascade do |t|
    t.bigint "snapshot_id", null: false
    t.integer "escalation_id"
    t.string "escalation_number", limit: 50
    t.string "escalation_type", limit: 100
    t.string "escalation_status", limit: 100
    t.string "escalation_group", limit: 255
    t.string "comp_id", limit: 10
    t.string "facility", limit: 70
    t.string "region_code", limit: 15
    t.text "mpn"
    t.string "fpn", limit: 150
    t.string "description", limit: 100
    t.text "manufacturer"
    t.text "supplier"
    t.string "customer", limit: 100
    t.datetime "date_opened"
    t.datetime "updated_date"
    t.datetime "closed_date"
    t.datetime "impact_date"
    t.integer "days_open"
    t.decimal "shortage_qty", precision: 18, scale: 4
    t.string "site_revenue_impact", limit: 200
    t.string "owner_name", limit: 255
    t.string "owner_email", limit: 255
    t.string "owner_role", limit: 255
    t.integer "age_current_owner"
    t.string "reason_code", limit: 255
    t.string "line_down", limit: 1
    t.string "item_on_allocation", limit: 1
    t.text "last_action_comments"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["snapshot_id", "escalation_number"], name: "index_csr_escalations_on_snapshot_id_and_escalation_number"
    t.index ["snapshot_id", "fpn"], name: "index_csr_escalations_on_snapshot_id_and_fpn"
    t.index ["snapshot_id", "mpn"], name: "index_csr_escalations_on_snapshot_id_and_mpn"
    t.index ["snapshot_id"], name: "index_csr_escalations_on_snapshot_id"
  end

  create_table "csr_osor_lines", force: :cascade do |t|
    t.bigint "snapshot_id", null: false
    t.bigint "part_key_id"
    t.string "cpn", limit: 200
    t.string "mpn", limit: 200
    t.string "fpn", limit: 200
    t.string "description", limit: 500
    t.string "manufacturer", limit: 200
    t.datetime "order_date"
    t.string "sold_to_bp", limit: 100
    t.string "bp_name", limit: 200
    t.string "ship_address", limit: 100
    t.string "cpo", limit: 100
    t.string "cpo_pos", limit: 50
    t.string "so", limit: 100
    t.string "so_pos", limit: 50
    t.string "seq", limit: 50
    t.string "po", limit: 100
    t.string "po_pos", limit: 50
    t.decimal "po_qty", precision: 18, scale: 4
    t.decimal "po_price", precision: 18, scale: 6
    t.datetime "po_confirm_date"
    t.datetime "po_change_date"
    t.string "po_activity", limit: 200
    t.string "error_condition", limit: 200
    t.string "so_status", limit: 100
    t.string "so_type", limit: 50
    t.string "load_code", limit: 100
    t.string "load_line_status", limit: 100
    t.string "load_general", limit: 100
    t.string "blocked", limit: 50
    t.string "block_codes", limit: 200
    t.string "inv_status", limit: 100
    t.decimal "baan_ordered", precision: 18, scale: 4
    t.decimal "spq", precision: 18, scale: 4
    t.decimal "spq_ordered", precision: 18, scale: 4
    t.decimal "moq", precision: 18, scale: 4
    t.decimal "stock", precision: 18, scale: 4
    t.decimal "block_qty", precision: 18, scale: 4
    t.decimal "free_qty", precision: 18, scale: 4
    t.decimal "price", precision: 18, scale: 6
    t.decimal "amount", precision: 18, scale: 4
    t.decimal "ppv", precision: 18, scale: 6
    t.string "so_whs", limit: 50
    t.string "whs", limit: 50
    t.string "inv_whs", limit: 50
    t.datetime "pdd"
    t.datetime "cdd"
    t.datetime "promdd"
    t.datetime "previous_cdd"
    t.datetime "cust_req_date"
    t.datetime "cust_rec_date"
    t.integer "days_previous_cdd"
    t.string "dates_condition", limit: 200
    t.boolean "miss", default: false, null: false
    t.string "kinaxis_unconfirmed", limit: 100
    t.string "kinaxis_confirmed", limit: 100
    t.string "ref_a", limit: 200
    t.string "ref_b", limit: 200
    t.datetime "source_last_update"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "project", limit: 100
    t.string "so_urgent", limit: 50
    t.string "po_ref_a", limit: 200
    t.string "load_spq_mismatch", limit: 50
    t.decimal "mauc_price", precision: 18, scale: 6
    t.decimal "so_ppv_price", precision: 18, scale: 6
    t.decimal "so_ppv_total", precision: 18, scale: 4
    t.index ["part_key_id"], name: "index_csr_osor_lines_on_part_key_id"
    t.index ["snapshot_id", "cpn"], name: "index_csr_osor_lines_on_snapshot_id_and_cpn"
    t.index ["snapshot_id", "cpo"], name: "index_csr_osor_lines_on_snapshot_id_and_cpo"
    t.index ["snapshot_id", "fpn"], name: "index_csr_osor_lines_on_snapshot_id_and_fpn"
    t.index ["snapshot_id", "miss"], name: "index_csr_osor_lines_on_snapshot_id_and_miss"
    t.index ["snapshot_id", "mpn"], name: "index_csr_osor_lines_on_snapshot_id_and_mpn"
    t.index ["snapshot_id", "part_key_id"], name: "index_csr_osor_lines_on_snapshot_id_and_part_key_id"
    t.index ["snapshot_id", "so"], name: "index_csr_osor_lines_on_snapshot_id_and_so"
    t.index ["snapshot_id"], name: "index_csr_osor_lines_on_snapshot_id"
  end

  create_table "csr_part_keys", force: :cascade do |t|
    t.string "key_value", limit: 400, null: false
    t.string "cpn", limit: 200, null: false
    t.string "mpn", limit: 200, null: false
    t.string "region", default: "Americas", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cpn"], name: "index_csr_part_keys_on_cpn"
    t.index ["mpn"], name: "index_csr_part_keys_on_mpn"
    t.index ["region", "key_value"], name: "index_csr_part_keys_on_region_and_key_value", unique: true
  end

  create_table "csr_snapshots", force: :cascade do |t|
    t.string "region", default: "Americas", null: false
    t.string "source_type", null: false
    t.string "status", default: "loading", null: false
    t.string "source_file"
    t.string "week_label"
    t.datetime "source_modified_at"
    t.datetime "started_at"
    t.datetime "activated_at"
    t.integer "row_count", default: 0, null: false
    t.integer "rejected_count", default: 0, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["region", "source_type", "status"], name: "index_csr_snapshots_on_region_and_source_type_and_status"
    t.index ["source_type", "source_modified_at"], name: "index_csr_snapshots_on_source_type_and_source_modified_at"
  end

  add_foreign_key "csr_escalations", "csr_snapshots", column: "snapshot_id"
  add_foreign_key "csr_osor_lines", "csr_part_keys", column: "part_key_id"
  add_foreign_key "csr_osor_lines", "csr_snapshots", column: "snapshot_id"
end
