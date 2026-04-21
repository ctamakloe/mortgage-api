module Api
  module V1
    class MortgageApplicationsController < Api::BaseController
      def show
        application = MortgageApplication.find(params[:id])

        # Assessment is computed on read to ensure consistency.
        # Could be persisted if computation becomes expensive.
        render json: assessment_response(application)
      end

      def create
        application = MortgageApplication.create(application_params)

        if application.persisted?
          render json: assessment_response(application), status: :created
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
