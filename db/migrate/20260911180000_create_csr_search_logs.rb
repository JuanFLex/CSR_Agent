class CreateCsrSearchLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :csr_search_logs do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :kind, null: false          # search | export
      t.string :search_type
      t.string :value
      t.integer :keys_found

      t.timestamps
    end

    add_index :csr_search_logs, [ :user_id, :created_at ]
  end
end
