require "rails_helper"

RSpec.describe ApiClient, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      client = described_class.new(
        name: "Test Client",
        api_key_digest: described_class.digest("secret"),
      )

      expect(client).to be_valid
    end

    it "requires a name" do
      client = described_class.new(api_key_digest: "digest")
      expect(client).not_to be_valid
    end

    it "requires an api_key_digest" do
      client = described_class.new(name: "Test Client")
      expect(client).not_to be_valid
    end
  end

  describe ".generate_raw_key" do
    it "generates a random key" do
      key1 = described_class.generate_raw_key
      key2 = described_class.generate_raw_key

      expect(key1).to be_present
      expect(key2).to be_present
      expect(key1).not_to eq(key2)
    end
  end

  describe ".digest" do
    it "generates a deterministic SHA256 digest" do
      key = "my-secret"

      digest1 = described_class.digest(key)
      digest2 = described_class.digest(key)

      expect(digest1).to eq(digest2)
    end
  end

  describe ".authenticate" do
    let!(:client_and_key) do
      raw = SecureRandom.hex(32)
      [
        described_class.create!(
          name: "Test Client",
          api_key_digest: described_class.digest(raw),
        ),
        raw,
      ]
    end

    let(:client) { client_and_key[0] }
    let(:raw_key) { client_and_key[1] }

    it "returns the client for a valid key" do
      expect(described_class.authenticate(raw_key)).to eq(client)
    end

    it "returns nil for an invalid key" do
      expect(described_class.authenticate("wrong")).to be_nil
    end

    it "returns nil for inactive clients" do
      client.update!(active: false)

      expect(described_class.authenticate(raw_key)).to be_nil
    end
  end

  describe "associations" do
    it "has many api_requests" do
      assoc = described_class.reflect_on_association(:api_requests)
      expect(assoc.macro).to eq(:has_many)
    end
  end
end
