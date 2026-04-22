class CreateApiRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :api_requests do |t|
      t.references :api_client, null: false, foreign_key: true
      t.string :method, null: false
      t.string :path, null: false
      t.integer :status, null: false
      t.jsonb :metadata, default: {}

      t.timestamps
    end
  end
end
