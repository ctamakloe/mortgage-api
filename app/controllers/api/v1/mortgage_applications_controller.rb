module Api
  module V1
    class MortgageApplicationsController < Api::BaseController
      def show
        application = MortgageApplication.find(params[:id])
        assessment = application.latest_assessment

        render json: {
          id: application.id,
          decision: assessment&.decision,
          metrics: assessment&.metrics,
          failures: assessment&.failures,
          explanation: assessment&.explanation,
          version: assessment&.version,
          computed_at: assessment&.computed_at,
        }
      end

      def create
        application = MortgageApplication.create(application_params)

        if application.persisted?
          ComputeAssessmentJob.perform_later(application.id)

          render json: { id: application.id, status: "processing" },
                 status: :created
        else
          render json: { errors: application.errors.full_messages }, status: :unprocessable_content
        end
      end

      private

      def application_params
        params.require(:mortgage_application).permit(
          :annual_income,
          :monthly_expenses,
          :deposit,
          :property_value,
          :term_years,
        )
      end

      def assessment_response(application)
        assessment = AffordabilityAssessmentService.new(application).call

        {
          id: application.id,
          decision: assessment.decision,
          metrics: assessment.metrics,
          failures: assessment.failures,
          explanation: assessment.explanation,
        }
      end
    end
  end
end
