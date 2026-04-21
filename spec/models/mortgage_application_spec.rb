require "rails_helper"

RSpec.describe MortgageApplication, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      app = MortgageApplication.new(
        annual_income: 80_000,
        monthly_expenses: 1_500,
        deposit: 50_000,
        property_value: 250_000,
        term_years: 25,
      )

      expect(app).to be_valid
    end

    it "is invalid when deposit is greater than property value" do
      app = MortgageApplication.new(
        annual_income: 80_000,
        monthly_expenses: 1_500,
        deposit: 300_000,
        property_value: 250_000,
        term_years: 25,
      )

      expect(app).not_to be_valid
      expect(app.errors[:deposit]).to include("must be less than property value")
    end
  end
end
