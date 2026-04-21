require "rails_helper"

RSpec.describe Assessment, type: :model do
  let(:application) do
    MortgageApplication.create!(
      annual_income: 80_000,
      monthly_expenses: 1_500,
      deposit: 50_000,
      property_value: 250_000,
      term_years: 25,
    )
  end

  subject do
    described_class.new(
      mortgage_application: application,
      decision: "approved",
      metrics: {},
      failures: [],
      explanation: "ok",
      version: 1,
      computed_at: Time.current,
    )
  end

  describe "validations" do
    it "is valid with valid attributes" do
      expect(subject).to be_valid
    end

    it "requires a decision" do
      subject.decision = nil
      expect(subject).not_to be_valid
    end

    it "requires computed_at" do
      subject.computed_at = nil
      expect(subject).not_to be_valid
    end

    it "enforces version uniqueness per application" do
      described_class.create!(
        mortgage_application: application,
        decision: "approved",
        metrics: {},
        failures: [],
        explanation: "ok",
        version: 1,
        computed_at: Time.current,
      )

      duplicate = described_class.new(
        mortgage_application: application,
        decision: "approved",
        metrics: {},
        failures: [],
        explanation: "ok",
        version: 1,
        computed_at: Time.current,
      )

      expect(duplicate).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to a mortgage application" do
      expect(subject.mortgage_application).to eq(application)
    end

    it "can have assessment events" do
      subject.save!

      event = subject.assessment_events.create!(
        event_type: "assessment_computed",
        payload: {},
      )

      expect(subject.assessment_events).to include(event)
    end
  end
end
