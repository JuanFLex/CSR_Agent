class CreateCsrPartKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :csr_part_keys do |t|
      # Key = TRIM(CLEAN(CPN)) & "|" & TRIM(CLEAN(MPN)) — build book Vol.2 §5.
      # Named key_value rather than key because KEY is reserved in T-SQL.
      t.string :key_value, null: false, limit: 400

      t.string :cpn, null: false, limit: 200
      t.string :mpn, null: false, limit: 200

      # Deliberately no FPN and no customer here. Both vary within a single
      # CPN|MPN — measured on the real export: 22 keys carry more than one FPN
      # and 14 more than one customer — so a column could only ever hold
      # whichever row happened to be read first. That is exactly the
      # List.First behaviour that makes the Excel quietly show one ship-to's
      # data when asked about another. They live on the order lines, where
      # they belong, and the UI shows all of them.
      t.string :region, null: false, default: "Americas"

      t.timestamps
    end

    # Part keys are a dimension: they survive across snapshots so that history
    # stays comparable week over week.
    add_index :csr_part_keys, [ :region, :key_value ], unique: true
    add_index :csr_part_keys, :cpn
    add_index :csr_part_keys, :mpn
  end
end
