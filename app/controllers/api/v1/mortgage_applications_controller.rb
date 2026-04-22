module Api
  module V1
    class MortgageApplicationsController < Api::BaseController
      def show
        application = MortgageApplication.find_by!(public_id: params[:id])

        render json: {
          id: application.public_id,
          annual_income: application.annual_income.to_f,
          monthly_expenses: application.monthly_expenses.to_f,
          deposit: application.deposit.to_f,
          property_value: application.property_value.to_f,
          term_years: application.term_years,
        }
      end

      def create
        application = MortgageApplication.create(application_params)

        if application.persisted?
          ComputeAssessmentJob.perform_later(application.id)

          render json: { id: application.public_id, status: "processing" },
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
    end
  end
end
