# The seven columns tOSOR shows that this app was not copying. The ColumnMap
# called them pivot helpers; they are not — the Excel puts them in front of the
# user. The real pivot helpers (SQPID, numitems, itemspq, itemmoq, pivotd) stay
# out, because tOSOR does not show them either.
class AddExposedOsorColumns < ActiveRecord::Migration[8.0]
  def change
    change_table :csr_osor_lines, bulk: true do |t|
      t.string  :project,       limit: 100   # sourg
      t.string  :so_urgent,     limit: 50    # SOS
      t.string  :po_ref_a,      limit: 200   # porefa
      t.string  :load_spq_mismatch, limit: 50 # LoadSPQMistmatch
      t.decimal :mauc_price,    precision: 18, scale: 6
      t.decimal :so_ppv_price,  precision: 18, scale: 6
      t.decimal :so_ppv_total,  precision: 18, scale: 4
    end
  end
end
