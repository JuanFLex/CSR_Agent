class CreateCsrCommitLines < ActiveRecord::Migration[8.0]
  def change
    create_table :csr_commit_lines do |t|
      # Both lookups go through the composite index below.
      t.references :snapshot, null: false, foreign_key: { to_table: :csr_snapshots }, index: false
      t.references :part_key, foreign_key: { to_table: :csr_part_keys }, index: false

      # --- identity -----------------------------------------------------
      # Normalized the way Csr::PartKey stores them. Csr::Commit::ColumnMap
      # is the single place the staging columns are married to these.
      t.string :cpn, limit: 200          # CPN
      t.string :mpn, limit: 200          # MPN

      # --- context ------------------------------------------------------
      # A key can carry more than one commit row (two customers, two
      # ship-tos). These say which, and never join the key.
      t.string :fpn,          limit: 200 # Part
      t.string :customer_id,  limit: 100 # Customer
      t.string :ship_address, limit: 100 # Delivery Address

      # --- the balance --------------------------------------------------
      t.date    :bucket_date, null: false          # Saturday naming the week
      t.decimal :balance, precision: 18, scale: 4  # forecast not yet committed, never positive

      t.timestamps
    end

    add_index :csr_commit_lines, [ :snapshot_id, :part_key_id ]
  end
end
