require "rails_helper"

RSpec.describe "Assessments API", type: :request do
  let!(:client_and_key) do
    raw = SecureRandom.hex(32)

    [
      ApiClient.create!(
        name: "Test Client",
        api_key_digest: ApiClient.digest(raw),
        active: true,
      ),
      raw,
    ]
  end

  let(:raw_key) { client_and_key[1] }

  let(:headers) do
    {
      "ACCEPT" => "application/json",
      "CONTENT_TYPE" => "application/json",
      "Authorization" => "Bearer #{raw_key}",
    }
  end

  let!(:application) do
    MortgageApplication.create!(
      annual_income: 80_000,
      monthly_expenses: 1_500,
      deposit: 50_000,
      property_value: 250_000,
      term_years: 25,
    )
  end

  describe "GET /api/v1/mortgage_applications/:id/assessment" do
    context "when assessment exists" do
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

      it "returns the latest assessment" do
        get "/api/v1/mortgage_applications/#{application.public_id}/assessment",
            headers: headers

        expect(response).to have_http_status(:ok)

        json = response.parsed_body

        expect(json["decision"]).to eq("approved")
        expect(json["metrics"]).to be_present
        expect(json["failures"]).to eq([])
        expect(json["version"]).to eq(1)
      end
    end

    context "when multiple assessments exist" do
      let!(:assessment_v1) do
        application.assessments.create!(
          decision: "approved",
          metrics: {},
          failures: [],
          explanation: "v1",
          version: 1,
          computed_at: 2.days.ago,
        )
      end

      let!(:assessment_v2) do
        application.assessments.create!(
          decision: "approved",
          metrics: {},
          failures: [],
          explanation: "v2",
          version: 2,
          computed_at: 1.day.ago,
        )
      end

      let!(:assessment_v3) do
        application.assessments.create!(
          decision: "declined",
          metrics: {},
          failures: ["risk"],
          explanation: "v3",
          version: 3,
          computed_at: Time.current,
        )
      end

      it "returns the highest version (latest)" do
        get "/api/v1/mortgage_applications/#{application.public_id}/assessment",
            headers: headers

        json = response.parsed_body

        expect(json["version"]).to eq(3)
      end

      it "is independent of computed_at ordering" do
        # break timestamp ordering deliberately
        assessment_v1.update!(computed_at: 1.day.from_now)

        get "/api/v1/mortgage_applications/#{application.public_id}/assessment",
            headers: headers

        json = response.parsed_body

        expect(json["version"]).to eq(3)
      end
    end

    context "when assessment is still processing" do
      it "returns processing status" do
        get "/api/v1/mortgage_applications/#{application.public_id}/assessment",
            headers: headers

        expect(response).to have_http_status(:accepted)

        json = response.parsed_body
        expect(json["status"]).to eq("processing")
      end
    end
  end

  describe "GET /api/v1/mortgage_applications/:id/assessments" do
    let!(:assessment_v1) do
      application.assessments.create!(
        decision: "approved",
        metrics: { "ltv" => 0.8 },
        failures: [],
        explanation: "Initial approval",
        version: 1,
        computed_at: 1.day.ago,
      )
    end

    let!(:assessment_v2) do
      application.assessments.create!(
        decision: "declined",
        metrics: { "ltv" => 0.95 },
        failures: ["LTV too high"],
        explanation: "Reassessment failed",
        version: 2,
        computed_at: Time.current,
      )
    end

    it "returns all assessments ordered by version descending" do
      get "/api/v1/mortgage_applications/#{application.public_id}/assessments",
          headers: headers

      expect(response).to have_http_status(:ok)

      json = response.parsed_body

      expect(json.length).to eq(2)
      expect(json.map { |a| a["version"] }).to eq([2, 1])
    end

    it "returns expected fields" do
      get "/api/v1/mortgage_applications/#{application.public_id}/assessments",
          headers: headers

      json = response.parsed_body.first

      expect(json).to include(
        "decision",
        "metrics",
        "failures",
        "explanation",
        "version",
        "computed_at",
      )
    end

    it "returns empty array when no assessments exist" do
      application.assessments.destroy_all

      get "/api/v1/mortgage_applications/#{application.public_id}/assessments",
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "logs the request" do
      expect do
        get "/api/v1/mortgage_applications/#{application.public_id}/assessments",
            headers: headers
      end.to change(ApiRequest, :count).by(1)
    end

    context "when many assessments exist" do
      before do
        (3..15).each do |v|
          application.assessments.create!(
            decision: "approved",
            metrics: {},
            failures: [],
            explanation: "extra",
            version: v,
            computed_at: Time.current,
          )
        end
      end

      it "limits results to 10 and keeps correct ordering" do
        get "/api/v1/mortgage_applications/#{application.public_id}/assessments",
            headers: headers

        json = response.parsed_body

        expect(json.length).to eq(10)

        versions = json.map { |a| a["version"] }
        expect(versions).to eq(versions.sort.reverse)
      end
    end
  end

  describe "consistency between endpoints" do
    let!(:assessment_v1) do
      application.assessments.create!(
        decision: "approved",
        metrics: {},
        failures: [],
        explanation: "v1",
        version: 1,
        computed_at: 1.day.ago,
      )
    end

    let!(:assessment_v2) do
      application.assessments.create!(
        decision: "declined",
        metrics: {},
        failures: [],
        explanation: "v2",
        version: 2,
        computed_at: Time.current,
      )
    end

    it "ensures /assessment matches first item of /assessments" do
      get "/api/v1/mortgage_applications/#{application.public_id}/assessments",
          headers: headers

      index_json = response.parsed_body

      get "/api/v1/mortgage_applications/#{application.public_id}/assessment",
          headers: headers

      show_json = response.parsed_body

      expect(show_json["version"]).to eq(index_json.first["version"])
    end
  end
end
