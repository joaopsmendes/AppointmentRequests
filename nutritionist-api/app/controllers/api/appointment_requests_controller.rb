module Api
  class AppointmentRequestsController < ApplicationController
    ERROR_STATUSES = { invalid: :unprocessable_entity, conflict: :conflict, not_found: :not_found }.freeze

    # GET /api/nutritionists/:nutritionist_id/appointment_requests?status=&page=&per_page=
    def index
      result = AppointmentRequests::ListAppointmentRequests.call(
        nutritionist_id: params[:nutritionist_id],
        status: params[:status],
        page: params[:page],
        per_page: params[:per_page]
      )

      render_list_result(result)
    end

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

    # PATCH /api/appointment_requests/:id  { "status": "accepted" | "rejected" }
    def update
      result = AppointmentRequests::Answer.call(
        id: params[:id],
        status: params.require(:status)
      )

      render_answer_result(result)
    end

    private
    
    def render_list_result(result)
      if result.success?
        render json: {
          data: result.records.map { |appointment_request| AppointmentRequestSerializer.render(appointment_request) },
          meta: Common::PaginationSerializer.render(result)
        }
      else
        render json: { errors: result.errors }, status: ERROR_STATUSES.fetch(result.status)
      end
    end
  
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
    
    def render_answer_result(result)
      if result.success?
        render json: {
          appointment_request: AppointmentRequestSerializer.render(result.appointment_request),
          auto_rejected_ids: result.auto_rejected_ids
        }
      else
        render json: { errors: result.errors }, status: ERROR_STATUSES.fetch(result.status)
      end
    end
  end
end