class CreateCsrOsorLines < ActiveRecord::Migration[8.0]
  def change
    create_table :csr_osor_lines do |t|
      t.references :snapshot, null: false, foreign_key: { to_table: :csr_snapshots }
      t.references :part_key, foreign_key: { to_table: :csr_part_keys }

      # --- identity -----------------------------------------------------
      # Column names follow the build book's vocabulary, not the staging
      # table's. Csr::Osor::ColumnMap is the single place the two are married.
      t.string   :cpn, limit: 200        # CPN_EDI
      t.string   :mpn, limit: 200        # MPN
      t.string   :fpn, limit: 200        # ITEM
      t.string   :description, limit: 500
      t.string   :manufacturer, limit: 200

      # --- customer / order --------------------------------------------
      t.datetime :order_date
      t.string   :sold_to_bp, limit: 100
      t.string   :bp_name, limit: 200
      t.string   :ship_address, limit: 100
      t.string   :cpo, limit: 100
      t.string   :cpo_pos, limit: 50
      t.string   :so, limit: 100
      t.string   :so_pos, limit: 50
      t.string   :seq, limit: 50

      # --- purchase order ----------------------------------------------
      t.string   :po, limit: 100
      t.string   :po_pos, limit: 50
      t.decimal  :po_qty, precision: 18, scale: 4
      t.decimal  :po_price, precision: 18, scale: 6
      t.datetime :po_confirm_date
      t.datetime :po_change_date
      t.string   :po_activity, limit: 200

      # --- status -------------------------------------------------------
      t.string   :error_condition, limit: 200   # "Condition"
      t.string   :so_status, limit: 100
      t.string   :so_type, limit: 50
      t.string   :load_code, limit: 100         # "LOAD"
      t.string   :load_line_status, limit: 100
      t.string   :load_general, limit: 100
      t.string   :blocked, limit: 50
      t.string   :block_codes, limit: 200
      t.string   :inv_status, limit: 100

      # --- quantities ---------------------------------------------------
      t.decimal  :baan_ordered, precision: 18, scale: 4   # open quantity
      t.decimal  :spq, precision: 18, scale: 4
      t.decimal  :spq_ordered, precision: 18, scale: 4
      t.decimal  :moq, precision: 18, scale: 4
      t.decimal  :stock, precision: 18, scale: 4
      t.decimal  :block_qty, precision: 18, scale: 4      # "BLOCK"
      t.decimal  :free_qty, precision: 18, scale: 4       # "FREE"
      t.decimal  :price, precision: 18, scale: 6
      t.decimal  :amount, precision: 18, scale: 4
      t.decimal  :ppv, precision: 18, scale: 6

      # --- warehouses ---------------------------------------------------
      t.string   :so_whs, limit: 50
      t.string   :whs, limit: 50
      t.string   :inv_whs, limit: 50

      # --- the dates the whole risk model turns on ----------------------
      t.datetime :pdd            # PLANDELDATE — need date
      t.datetime :cdd            # COMMDELDATE — committed delivery / ETD
      t.datetime :promdd         # PROMDELDATE
      t.datetime :previous_cdd   # PREVIOUSCOMMDELDATE
      t.datetime :cust_req_date
      t.datetime :cust_rec_date
      t.integer  :days_previous_cdd
      t.string   :dates_condition, limit: 200

      # A line is a "miss" when the committed date lands after the need date
      # (CDD > PDD). Computed once at ingest so risk queries stay simple counts
      # rather than per-row date arithmetic.
      t.boolean  :miss, null: false, default: false

      t.string   :kinaxis_unconfirmed, limit: 100
      t.string   :kinaxis_confirmed, limit: 100
      t.string   :ref_a, limit: 200
      t.string   :ref_b, limit: 200

      # Staging row's own watermark, kept for tracing a line back to its load.
      t.datetime :source_last_update

      t.timestamps
    end

    # The hot path: "all lines for these keys in the active snapshot".
    add_index :csr_osor_lines, [ :snapshot_id, :part_key_id ]
    add_index :csr_osor_lines, [ :snapshot_id, :miss ]

    # Search entry points from INPUT_PANEL (CPN, MPN, CPO+Line, SO, FPN).
    add_index :csr_osor_lines, [ :snapshot_id, :cpo ]
    add_index :csr_osor_lines, [ :snapshot_id, :so ]
    add_index :csr_osor_lines, [ :snapshot_id, :cpn ]
    add_index :csr_osor_lines, [ :snapshot_id, :mpn ]
    add_index :csr_osor_lines, [ :snapshot_id, :fpn ]
  end
end
