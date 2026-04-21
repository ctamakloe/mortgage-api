class ComputeAssessmentJob < ApplicationJob
  queue_as :default

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
    end
  end
end
