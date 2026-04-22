require "rails_helper"

RSpec.describe "MortgageApplications", type: :request do
  include ActiveJob::TestHelper

  let!(:client_and_key) do
    raw = SecureRandom.hex(32)
    [
      ApiClient.create!(
        name: "Test Client",
        api_key_digest: ApiClient.digest(raw),
      ),
      raw,
    ]
  end

  let(:client) { client_and_key[0] }
  let(:raw_key) { client_and_key[1] }

  let(:headers) do
    {
      "ACCEPT" => "application/json",
      "CONTENT_TYPE" => "application/json",
      "Authorization" => "Bearer #{raw_key}",
    }
  end

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
        post "/api/v1/mortgage_applications", params: valid_params.to_json,
                                              headers: headers
      end

      expect(response).to have_http_status(:created)

      json = response.parsed_body
      application = MortgageApplication.find_by!(public_id: json["id"])
      assessment = application.latest_assessment

      expect(assessment).to be_present
      expect(assessment.decision).to eq("approved")
      expect(assessment.metrics).to be_present
      expect(assessment.failures).to eq([])
      expect(assessment.version).to eq(1)
    end

    it "returns validation errors for invalid input" do
      post "/api/v1/mortgage_applications",
           params: { mortgage_application: { annual_income: nil } }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)

      json = response.parsed_body
      expect(json["errors"]).to be_present
    end

    it "logs the request" do
      expect do
        post "/api/v1/mortgage_applications", params: valid_params.to_json,
                                              headers: headers
      end.to change(ApiRequest, :count).by(1)
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

    it "returns the application" do
      get "/api/v1/mortgage_applications/#{application.public_id}", headers: headers

      expect(response).to have_http_status(:ok)

      json = response.parsed_body

      expect(json["id"]).to eq(application.public_id)
      expect(json["annual_income"]).to eq(80_000)
      expect(json["monthly_expenses"]).to eq(1_500)
      expect(json["deposit"]).to eq(50_000)
      expect(json["property_value"]).to eq(250_000)
      expect(json["term_years"]).to eq(25)

      # Ensure assessment is NOT included anymore
      expect(json).not_to have_key("decision")
      expect(json).not_to have_key("metrics")
      expect(json).not_to have_key("failures")
      expect(json).not_to have_key("version")
    end
  end
end
