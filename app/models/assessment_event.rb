class AssessmentEvent < ApplicationRecord
  belongs_to :assessment

  validates :event_type, presence: true
end
