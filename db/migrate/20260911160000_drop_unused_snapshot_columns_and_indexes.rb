# Six indexes no query uses, and two snapshot columns nothing reads.
#
# The lines are never looked up by CPN or MPN — the keys are, in csr_part_keys
# — and the bare snapshot_id indexes are prefixes of composites that already
# exist. Escalations are only ever read by snapshot and MPN. Every index here
# was being rebuilt on each load, which is a truncate+insert of 12k rows.
class DropUnusedSnapshotColumnsAndIndexes < ActiveRecord::Migration[8.0]
  def change
    remove_index :csr_osor_lines, [ :snapshot_id, :cpn ]
    remove_index :csr_osor_lines, [ :snapshot_id, :mpn ]
    remove_index :csr_osor_lines, :snapshot_id
    remove_index :csr_escalations, [ :snapshot_id, :fpn ]
    remove_index :csr_escalations, [ :snapshot_id, :escalation_number ]
    remove_index :csr_escalations, :snapshot_id

    # week_label was for the weekly files and is still unwritten; started_at
    # was written by the ingest and read by nobody.
    remove_column :csr_snapshots, :week_label, :string
    remove_column :csr_snapshots, :started_at, :datetime
  end
end
