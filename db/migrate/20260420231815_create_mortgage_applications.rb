class CreateMortgageApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :mortgage_applications do |t|
      t.decimal :annual_income, precision: 12, scale: 2
      t.decimal :monthly_expenses, precision: 12, scale: 2
      t.decimal :deposit, precision: 12, scale: 2
      t.decimal :property_value, precision: 12, scale: 2
      t.integer :term_years

      t.timestamps
    end
  end
end
