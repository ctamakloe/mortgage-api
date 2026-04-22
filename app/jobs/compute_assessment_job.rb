class ComputeAssessmentJob < ApplicationJob
  queue_as :default

  retry_on StandardError, attempts: 3, wait: 1.minute
  discard_on ActiveJob::DeserializationError

  def perform(application_id)
    application = MortgageApplication.find(application_id)

    result = AffordabilityAssessmentService.new(application).call

    ApplicationRecord.transaction do
      assessment = application.assessments.create!(
        version: application.next_assessment_version,
        decision: result.decision,
        metrics: result.metrics,
        failures: result.failures,
        explanation: result.explanation,
        computed_at: Time.current,
      )

      assessment.assessment_events.create!(
        event_type: "assessment_computed",
        payload: {
          decision: assessment.decision,
          version: assessment.version,
        },
      )

      application.mark_completed!
    end
  rescue StandardError => e
    handle_failure(application, e) if application
    raise
  end

  private

  def handle_failure(application, error)
    Rails.logger.error(
      "[ComputeAssessmentJob] application_id=#{application.id} " \
      "public_id=#{application.public_id} " \
      "error=#{error.class} message=#{error.message} " \
      "backtrace=#{error.backtrace&.first(5)&.join(' | ')}",
    )

    ApplicationRecord.transaction do
      application.assessments.create!(
        version: application.next_assessment_version,
        decision: "failed",
        metrics: {},
        failures: [error.message],
        explanation: "Assessment failed",
        computed_at: Time.current,
      )

      application.mark_failed!
    end
  end
end
