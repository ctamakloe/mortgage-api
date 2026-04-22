class ApiClient < ApplicationRecord
  has_many :api_requests, dependent: :destroy

  validates :name, presence: true
  validates :api_key_digest, presence: true

  def self.generate_raw_key
    SecureRandom.hex(32)
  end

  def self.digest(key)
    OpenSSL::Digest::SHA256.hexdigest(key)
  end

  def self.authenticate(raw_key)
    return nil if raw_key.blank?

    hashed_key = digest(raw_key)
    find_by(api_key_digest: hashed_key, active: true)
  end
end
