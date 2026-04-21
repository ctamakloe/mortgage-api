require "rails_helper"

RSpec.describe AssessmentEvent, type: :model do
  it "is valid with valid attributes" do
    app = MortgageApplication.create!(
      annual_income: 80_000,
      monthly_expenses: 1_500,
      deposit: 50_000,
      property_value: 250_000,
      term_years: 25,
    )

    assessment = app.assessments.create!(
      version: 1,
      decision: "approved",
      metrics: {},
      failures: [],
      explanation: "test",
      computed_at: Time.current,
    )

    event = described_class.new(
      assessment: assessment,
      event_type: "assessment_computed",
    )

    expect(event).to be_valid
  end
end
