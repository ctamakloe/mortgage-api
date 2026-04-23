module Api
  module V1
    class AssessmentsController < Api::BaseController
      def index
        application = MortgageApplication.find_by!(public_id: params[:mortgage_application_id])

        assessments = application.assessments.limit(10)

        render json: assessments.map { |a| serialize(a) }
      end

      def show
        application = MortgageApplication.find_by!(public_id: params[:mortgage_application_id])
        assessment = application.latest_assessment

        if assessment
          render json: serialize(assessment), status: :ok
        else
          render json: { status: "processing" }, status: :accepted
        end
      end

      private

      def serialize(a)
        {
          decision: a.decision,
          metrics: a.metrics,
          failures: a.failures,
          explanation: a.explanation,
          version: a.version,
          computed_at: a.computed_at,
        }
      end
    end
  end
end
