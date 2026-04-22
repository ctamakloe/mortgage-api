class ApiRequest < ApplicationRecord
  belongs_to :api_client

  validates :method, :path, :status, presence: true
end
