class MortgageApplication < ApplicationRecord
  STATUSES = %w[processing completed failed].freeze

  before_validation :set_public_id, on: :create

  validates :public_id, presence: true, uniqueness: true

  validates :annual_income, :monthly_expenses,
            :deposit, :property_value, :term_years,
            presence: true

  validates :annual_income, :monthly_expenses,
            :deposit, :property_value,
            numericality: { greater_than_or_equal_to: 0 }

  validates :term_years,
            numericality: { only_integer: true, greater_than: 0 }

  validate :deposit_less_than_property_value

  validates :status, inclusion: { in: STATUSES }

  has_many :assessments, dependent: :restrict_with_exception

  def deposit_less_than_property_value
    return if deposit.blank? || property_value.blank?

    return unless deposit >= property_value

    errors.add(:deposit, "must be less than property value")
  end

  def latest_assessment
    assessments.order(computed_at: :desc).first
  end

  def next_assessment_version
    (assessments.maximum(:version) || 0) + 1
  end

  def mark_completed!
    update!(status: "completed")
  end

  def mark_failed!
    update!(status: "failed")
  end

  private

  def set_public_id
    self.public_id ||= SecureRandom.uuid
  end
end
