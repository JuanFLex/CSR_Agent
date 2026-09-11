class CreateUserSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :user_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.integer :duration_seconds
      t.string :sign_out_reason
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end
  end
end
