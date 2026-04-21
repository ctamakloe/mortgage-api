require "rails_helper"

RSpec.describe "MortgageApplications", type: :request do
  include ActiveJob::TestHelper

  describe "POST /api/v1/mortgage_applications" do
    let(:valid_params) do
      {
        mortgage_application: {
          annual_income: 80_000,
          monthly_expenses: 1_500,
          deposit: 50_000,
          property_value: 250_000,
          term_years: 25,
        },
      }
    end

    it "creates an application and computes assessment asynchronously" do
      perform_enqueued_jobs do
        post "/api/v1/mortgage_applications", params: valid_params
      end

      expect(response).to have_http_status(:created)

      json = response.parsed_body
      application = MortgageApplication.find(json["id"])
      assessment = application.latest_assessment

      expect(assessment).to be_present
      expect(assessment.decision).to eq("approved")
      expect(assessment.metrics).to be_present
      expect(assessment.failures).to eq([])
      expect(assessment.version).to eq(1)
    end

    it "returns validation errors for invalid input" do
      post "/api/v1/mortgage_applications", params: {
        mortgage_application: { annual_income: nil },
      }

      expect(response).to have_http_status(:unprocessable_content)

      json = response.parsed_body
      expect(json["errors"]).to be_present
    end
  end

  describe "GET /api/v1/mortgage_applications/:id" do
    let!(:application) do
      MortgageApplication.create!(
        annual_income: 80_000,
        monthly_expenses: 1_500,
        deposit: 50_000,
        property_value: 250_000,
        term_years: 25,
      )
    end

    let!(:assessment) do
      application.assessments.create!(
        decision: "approved",
        metrics: { "ltv" => 0.8 },
        failures: [],
        explanation: "Within acceptable thresholds",
        version: 1,
        computed_at: Time.current,
      )
    end

    it "returns the application with latest assessment" do
      get "/api/v1/mortgage_applications/#{application.id}"

      expect(response).to have_http_status(:ok)

      json = response.parsed_body

      expect(json["id"]).to eq(application.id)
      expect(json["decision"]).to eq("approved")
      expect(json["metrics"]).to be_present
      expect(json["failures"]).to eq([])
      expect(json["version"]).to eq(1)
    end
  end
end
