class MortgageApplication < ApplicationRecord
  validates :annual_income, :monthly_expenses,
            :deposit, :property_value, :term_years,
            presence: true

  validates :annual_income, :monthly_expenses,
            :deposit, :property_value,
            numericality: { greater_than_or_equal_to: 0 }

  validates :term_years,
            numericality: { only_integer: true, greater_than: 0 }

  validate :deposit_less_than_property_value

  def deposit_less_than_property_value
    return if deposit.blank? || property_value.blank?

    return unless deposit >= property_value

    errors.add(:deposit, "must be less than property value")
  end
end
