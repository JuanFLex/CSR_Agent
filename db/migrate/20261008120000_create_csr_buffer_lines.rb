class CreateCsrBufferLines < ActiveRecord::Migration[8.0]
  def change
    create_table :csr_buffer_lines do |t|
      # Both lookups go through the composite index below.
      t.references :snapshot, null: false, foreign_key: { to_table: :csr_snapshots }, index: false
      t.references :part_key, foreign_key: { to_table: :csr_part_keys }, index: false

      # --- identity -----------------------------------------------------
      # Normalized the way Csr::PartKey stores them. Csr::Buffer::ColumnMap
      # is the single place the staging names are married to these.
      t.string :cpn, limit: 200          # CPN
      t.string :mpn, limit: 200          # MANUFACTURER_PART

      # --- context ------------------------------------------------------
      # A key can carry more than one buffer row (FCS- and FCS1- twins, two
      # suppliers, two ship-tos). These say which, and never join the key.
      t.string :fpn,          limit: 200 # FCP_PART
      t.string :site,         limit: 50  # FCP_SITE
      t.string :supplier,     limit: 255 # SUPPLIER_NAME
      t.string :customer_id,  limit: 100 # CUSTOMER_ID
      t.string :ship_address, limit: 100 # DELIVERY_ADDRESS

      # --- the projection -----------------------------------------------
      t.decimal :safety_stock, precision: 18, scale: 4 # SAFETY_STOCK_CONSIDER_SPQ
      t.date    :bucket_date, null: false              # Saturday naming the week
      t.decimal :vs_ss, precision: 18, scale: 4        # balance / safety stock

      t.timestamps
    end

    add_index :csr_buffer_lines, [ :snapshot_id, :part_key_id ]
  end
end
