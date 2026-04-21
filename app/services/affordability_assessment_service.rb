class AffordabilityAssessmentService
  Result = Struct.new(
    :decision,
    :metrics,
    :failures,
    :explanation,
    keyword_init: true,
  )

  MAX_LTV = 0.9
  MAX_DTI = 0.4
  INCOME_MULTIPLIER = 4.0

  def initialize(application)
    @app = application
  end

  def call
    Result.new(
      decision: decision,
      metrics: metrics,
      failures: failures,
      explanation: explanation,
    )
  end

  private

  def loan_amount
    @loan_amount ||= @app.property_value - @app.deposit
  end

  def ltv
    @ltv ||= loan_amount / @app.property_value.to_f
  end

  def dti
    monthly_income = @app.annual_income / 12.0
    @dti ||= @app.monthly_expenses / monthly_income
  end

  def max_borrow
    @max_borrow ||= @app.annual_income * INCOME_MULTIPLIER
  end

  def metrics
    {
      loan_amount: loan_amount.round,
      ltv: ltv.round(2),
      dti: dti.round(2),
      max_borrow: max_borrow.round,
    }
  end

  def failures
    @failures ||= begin
      f = []
      f << ltv_failure if ltv > MAX_LTV
      f << dti_failure if dti > MAX_DTI
      f << borrowing_failure if loan_amount > max_borrow
      f.compact
    end
  end

  def decision
    failures.empty? ? "approved" : "declined"
  end

  def explanation
    if decision == "approved"
      "Application meets affordability criteria"
    else
      failures.join(", ")
    end
  end

  def ltv_failure
    "LTV (#{ltv.round(2)}) exceeds maximum (#{MAX_LTV})"
  end

  def dti_failure
    "DTI (#{dti.round(2)}) exceeds maximum (#{MAX_DTI})"
  end

  def borrowing_failure
    "Loan amount (#{loan_amount}) exceeds maximum borrow (#{max_borrow.round})"
  end
end
