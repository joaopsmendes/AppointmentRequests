module AppointmentRequests
  class ListAppointmentRequests
    Result = Struct.new(:status, :records, :page, :per_page, :total_count, :total_pages, :errors, keyword_init: true) do
      def success?
        status == :ok
      end
    end

    def self.call(nutritionist_id:, status: nil, page: 1, per_page: nil)
      nutritionist = Nutritionist.find_by(id: nutritionist_id)
      return failure(:not_found, ["Nutritionist not found"]) unless nutritionist

      per_page = nil unless per_page.to_i.positive?

      status = status.presence || "pending"
      unless AppointmentRequest.statuses.key?(status)
        return failure(:invalid, ["Status must be one of: #{AppointmentRequest.statuses.keys.join(', ')}"])
      end

      paginated_scope = nutritionist.appointment_requests
                                    .where(status: status)
                                    .includes(:guest, :service)
                                    .order(:scheduled_at, :id)
                                    .page(page)
                                    .per(per_page, max_per_page: 25)

      Result.new(
        status: :ok,
        records: paginated_scope,
        page: paginated_scope.current_page,
        per_page: paginated_scope.limit_value,
        total_count: paginated_scope.total_count,
        total_pages: paginated_scope.total_pages,
        errors: []
      )
    end

    def self.failure(status, errors)
      Result.new(status: status, records: [], errors: errors)
    end

    private_class_method :failure
  end
end