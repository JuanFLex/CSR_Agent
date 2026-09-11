class CreateCsrEscalations < ActiveRecord::Migration[8.0]
  def change
    create_table :csr_escalations do |t|
      t.references :snapshot, null: false, foreign_key: { to_table: :csr_snapshots }

      # Identity of the escalation itself.
      t.integer :escalation_id
      t.string  :escalation_number, limit: 50
      t.string  :escalation_type,   limit: 100
      t.string  :escalation_status, limit: 100
      t.string  :escalation_group,  limit: 255
      t.string  :comp_id,           limit: 10
      t.string  :facility,          limit: 70
      t.string  :region_code,       limit: 15

      # What it was raised against. CSR_FET carries no CPN, so these are the
      # only handles back to a part: both are stored normalized, the same way
      # Csr::PartKey normalizes, so the join can be an equality.
      t.text    :mpn
      t.string  :fpn,               limit: 150
      t.string  :description,       limit: 100
      t.text    :manufacturer
      t.text    :supplier
      t.string  :customer,          limit: 100

      # Age, impact and who is holding it.
      t.datetime :date_opened
      t.datetime :updated_date
      t.datetime :closed_date
      t.datetime :impact_date
      t.integer  :days_open
      t.decimal  :shortage_qty, precision: 18, scale: 4
      t.string   :site_revenue_impact, limit: 200
      t.string   :owner_name,  limit: 255
      t.string   :owner_email, limit: 255
      t.string   :owner_role,  limit: 255
      t.integer  :age_current_owner
      t.string   :reason_code, limit: 255
      t.string   :line_down,          limit: 1
      t.string   :item_on_allocation, limit: 1
      t.text     :last_action_comments

      t.timestamps
    end

    add_index :csr_escalations, [ :snapshot_id, :mpn ]
    add_index :csr_escalations, [ :snapshot_id, :fpn ]
    add_index :csr_escalations, [ :snapshot_id, :escalation_number ]
  end
end
