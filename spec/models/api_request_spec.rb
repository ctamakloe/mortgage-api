require "rails_helper"

RSpec.describe ApiRequest, type: :model do
  let(:client) do
    ApiClient.create!(
      name: "Test Client",
      api_key_digest: ApiClient.digest("secret"),
    )
  end

  describe "validations" do
    it "is valid with valid attributes" do
      request = described_class.new(
        api_client: client,
        method: "POST",
        path: "/api/v1/mortgage_applications",
        status: 201,
      )

      expect(request).to be_valid
    end

    it "requires method" do
      request = described_class.new(api_client: client, path: "/x", status: 200)
      expect(request).not_to be_valid
    end

    it "requires path" do
      request = described_class.new(api_client: client, method: "GET", status: 200)
      expect(request).not_to be_valid
    end

    it "requires status" do
      request = described_class.new(api_client: client, method: "GET", path: "/x")
      expect(request).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to api_client" do
      assoc = described_class.reflect_on_association(:api_client)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end
end
