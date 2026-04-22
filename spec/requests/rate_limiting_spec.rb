require "rails_helper"

RSpec.describe "Rate limiting", type: :request do
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
      "Authorization" => "Bearer #{raw_key}",
      "ACCEPT" => "application/json",
      "CONTENT_TYPE" => "application/json",
    }
  end

  it "returns 429 when rate limit is exceeded" do
    stub_const("Authenticable::RATE_LIMIT", 2)

    2.times do
      get "/api/v1/mortgage_applications/1/assessment", headers: headers
    end

    get "/api/v1/mortgage_applications/1/assessment", headers: headers

    expect(response).to have_http_status(:too_many_requests)
  end
end
