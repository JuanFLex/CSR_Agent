class AddWeeklyHistory < ActiveRecord::Migration[8.0]
  def change
    # The buffer report's "Allocated Customer On Hand": per part, like the
    # safety stock beside it, so it repeats on every week of the row.
    add_column :csr_buffer_lines, :allocated_on_hand, :decimal, precision: 18, scale: 4

    # The Demand Comparison report's two snapshots, week by week. Bucket i of
    # both arrays is the week old_snapshot_on + 7 * i.
    add_column :csr_demand_lines, :old_snapshot_on, :date
    add_column :csr_demand_lines, :new_snapshot_on, :date
    add_column :csr_demand_lines, :old_weeks, :decimal, precision: 18, scale: 4, array: true
    add_column :csr_demand_lines, :new_weeks, :decimal, precision: 18, scale: 4, array: true

    # One row per key and report week, kept for good: the snapshots are pruned
    # to two, so this is the only history the portal has. Each weekly source
    # fills its own columns.
    create_table :csr_weekly_positions do |t|
      t.references :part_key, null: false, foreign_key: { to_table: :csr_part_keys }, index: false
      t.date :week, null: false # the Saturday the report's weeks start on

      # --- buffer -------------------------------------------------------
      t.decimal :safety_stock,      precision: 18, scale: 4
      t.decimal :allocated_on_hand, precision: 18, scale: 4
      t.decimal :min_vs_ss,         precision: 18, scale: 4 # lowest projected week, as a multiple of SS

      # --- demand -------------------------------------------------------
      t.decimal :demand_total, precision: 18, scale: 4 # the new snapshot's demand over the whole horizon
      t.decimal :lt_variation, precision: 18, scale: 4 # pieces it moved inside lead time

      t.timestamps
    end

    add_index :csr_weekly_positions, [ :part_key_id, :week ], unique: true
  end
end
