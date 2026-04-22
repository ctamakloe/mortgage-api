class CreateApiClients < ActiveRecord::Migration[8.1]
  def change
    create_table :api_clients do |t|
      t.string :name, null: false
      t.string :api_key_digest, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :api_clients, :api_key_digest, unique: true
  end
end
