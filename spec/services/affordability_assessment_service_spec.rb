require "rails_helper"

RSpec.describe AffordabilityAssessmentService do
  let(:application) do
    MortgageApplication.new(
      annual_income: 80_000,
      monthly_expenses: 1_500,
      deposit: 50_000,
      property_value: 250_000,
      term_years: 25,
    )
  end

  subject(:result) { described_class.new(application).call }

  describe "#call" do
    it "approves a low-risk application" do
      expect(result.decision).to eq("approved")
      expect(result.failures).to be_empty
    end

    it "declines when LTV is too high" do
      application.deposit = 10_000

      expect(result.decision).to eq("declined")
      expect(result.failures.join).to include("LTV")
    end

    it "declines when DTI is too high" do
      application.monthly_expenses = 5000

      expect(result.decision).to eq("declined")
      expect(result.failures.join).to include("DTI")
    end

    it "declines when loan exceeds max borrow" do
      application.property_value = 500_000

      expect(result.decision).to eq("declined")
      expect(result.failures.join).to include("Loan amount")
    end

    it "returns detailed metrics" do
      expect(result.metrics).to include(:ltv, :dti, :loan_amount, :max_borrow)
    end
  end
end
