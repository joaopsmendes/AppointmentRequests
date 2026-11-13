module Api
  class AppointmentRequestsController < ApplicationController
    ERROR_STATUSES = { invalid: :unprocessable_entity, conflict: :conflict, not_found: :not_found }.freeze

    # POST /api/appointment_requests
    def create
      result = AppointmentRequests::Create.call(
        name: create_params[:name],
        email: create_params[:email],
        service_id: create_params[:service_id],
        scheduled_at: create_params[:scheduled_at]
      )

      render_result(result)
    end

    private

    def create_params
      params.require(:appointment_request).permit(:name, :email, :service_id, :scheduled_at)
    end

    def render_result(result)
      if result.success?
        render json: AppointmentRequestSerializer.render(result.appointment_request), status: :created
      else
        render json: { errors: result.errors }, status: ERROR_STATUSES.fetch(result.status)
      end
    end
  end
end