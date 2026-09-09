class CreateCsrSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :csr_snapshots do |t|
      t.string  :region,      null: false, default: "Americas"
      t.string  :source_type, null: false          # osor | buffer | commit | demand | escalation
      t.string  :status,      null: false, default: "loading"  # loading | active | failed | superseded

      # Where the data came from: the staging table name for OSOR, the uploaded
      # filename for the weekly Kinaxis exports.
      t.string  :source_file
      t.string  :week_label                        # "W11" for the weekly files; null for OSOR

      # Freshness watermark. For OSOR this is MAX(lastupdate) observed in
      # CSR_OSOR_AMERICAS; it is how the ingest knows the DBA's truncate+load
      # produced something new without that process having to change.
      t.datetime :source_modified_at

      t.datetime :started_at
      t.datetime :activated_at
      t.integer  :row_count,        null: false, default: 0
      t.integer  :rejected_count,   null: false, default: 0
      t.text     :notes                            # why a load failed, or which rows were rejected

      t.timestamps
    end

    # Every read filters "the active snapshot for this source", so that is the
    # index that matters.
    add_index :csr_snapshots, [ :region, :source_type, :status ]
    add_index :csr_snapshots, [ :source_type, :source_modified_at ]
  end
end
