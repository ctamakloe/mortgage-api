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

  describe "assessment ordering" do
    let!(:application) do
      MortgageApplication.create!(
        annual_income: 80_000,
        monthly_expenses: 1_500,
        deposit: 50_000,
        property_value: 250_000,
        term_years: 25,
        status: "processing",
      )
    end

    let!(:assessment_v1) do
      application.assessments.create!(
        version: 1,
        decision: "approved",
        metrics: {},
        failures: [],
        explanation: "v1",
        computed_at: 2.days.ago,
      )
    end

    let!(:assessment_v2) do
      application.assessments.create!(
        version: 2,
        decision: "approved",
        metrics: {},
        failures: [],
        explanation: "v2",
        computed_at: 1.day.ago,
      )
    end

    let!(:assessment_v3) do
      application.assessments.create!(
        version: 3,
        decision: "declined",
        metrics: {},
        failures: ["too risky"],
        explanation: "v3",
        computed_at: Time.current,
      )
    end

    it "returns assessments ordered by version descending" do
      versions = application.assessments.map(&:version)

      expect(versions).to eq([3, 2, 1])
    end

    it "returns latest_assessment as highest version" do
      expect(application.latest_assessment.version).to eq(3)
    end

    it "is independent of computed_at ordering" do
      # deliberately break timestamp ordering
      assessment_v1.update!(computed_at: 1.day.from_now)

      # version ordering should still win
      versions = application.assessments.map(&:version)
      expect(versions).to eq([3, 2, 1])

      expect(application.latest_assessment.version).to eq(3)
    end
  end
end
