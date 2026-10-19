class CreateCsrDemandLines < ActiveRecord::Migration[8.0]
  def change
    create_table :csr_demand_lines do |t|
      # Both lookups go through the composite index below.
      t.references :snapshot, null: false, foreign_key: { to_table: :csr_snapshots }, index: false
      t.references :part_key, foreign_key: { to_table: :csr_part_keys }, index: false

      # --- identity -----------------------------------------------------
      # Normalized the way Csr::PartKey stores them. Csr::Demand::ColumnMap
      # is the single place the staging columns are married to these.
      t.string :cpn, limit: 200          # CPN
      t.string :mpn, limit: 200          # MPN

      # --- context ------------------------------------------------------
      # A key can carry more than one demand row (two FPNs, two ship-tos).
      # These say which, and never join the key.
      t.string :fpn,          limit: 200 # FCP Part
      t.string :customer_name, limit: 100 # Customer Name
      t.string :ship_address, limit: 100 # Delivery Address
      t.string :company,      limit: 50  # Company

      # --- the movement -------------------------------------------------
      t.string  :status, limit: 100                 # the report's own verdict on the part
      t.integer :eff_lead_time                      # days
      # The pct columns are ratios (0.25 is 25%), not percentages.
      t.decimal :lt_variation,        precision: 18, scale: 4 # pieces moved inside lead time
      t.decimal :lt_variation_pct,    precision: 18, scale: 6
      t.decimal :total_variation,     precision: 18, scale: 4 # pieces moved in total
      t.decimal :total_variation_pct, precision: 18, scale: 6

      t.timestamps
    end

    add_index :csr_demand_lines, [ :snapshot_id, :part_key_id ]
  end
end
