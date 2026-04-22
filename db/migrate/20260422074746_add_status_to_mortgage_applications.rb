class AddStatusToMortgageApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :mortgage_applications, :status, :string, null: false, default: "processing"
    add_index :mortgage_applications, :status
  end
end
