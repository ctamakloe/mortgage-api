class AddPublicIdToMortgageApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :mortgage_applications, :public_id, :uuid, default: "gen_random_uuid()", null: false
    add_index :mortgage_applications, :public_id, unique: true
  end
end
