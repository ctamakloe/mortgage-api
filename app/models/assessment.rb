class Assessment < ApplicationRecord
  belongs_to :mortgage_application
  has_many :assessment_events, dependent: :destroy

  validates :decision, presence: true
  validates :computed_at, presence: true
  validates :version, presence: true, uniqueness: { scope: :mortgage_application_id }
end
