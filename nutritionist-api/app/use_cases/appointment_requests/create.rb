module AppointmentRequests
  class Create
    Result = Struct.new(:status, :appointment_request, :errors, keyword_init: true) do
      def success?
        status == :created
      end
    end

    PENDING_REQUEST_MESSAGE = "You already have a pending appointment request".freeze
    SLOT_TAKEN_MESSAGE = "This time slot is no longer available".freeze

    def self.call(name:, email:, service_id:, scheduled_at:)
      result = nil

      begin
        # Guest and request are created together: if the request fails, the new guest is rolled back.
        ActiveRecord::Base.transaction do
          result = create_request(name, email, service_id, scheduled_at)
          if !result.success?
            raise ActiveRecord::Rollback
          end
        end

        return result
      rescue ActiveRecord::RecordNotUnique
      # Two concurrent requests from the same guest can both pass the validation;
      # the partial unique index one_pending_per_guest rejects the second one.
        Rails.logger.info("[Create] concurrent request refused by one_pending_per_guest service_id=#{service_id}")
        failure(:conflict, [PENDING_REQUEST_MESSAGE])
      end
    end

    def self.create_request(name, email, service_id, scheduled_at)
      guest = Guest.create_or_find_by(email: email) { |new_guest| new_guest.name = name }
      return failure(:invalid, guest.errors.full_messages) unless guest.persisted?

      service = Service.find_by(id: service_id)
      return failure(:not_found, ["Service not found"]) unless service

      # Pessimistic lock: creates and accepts for the same nutritionist run one at a time,
      # so slot_taken? always reads the latest committed schedule
      Nutritionist.lock.find(service.nutritionist_id)

      reject_expired_requests(guest)

      appointment_request = AppointmentRequest.new(
        guest: guest,
        service: service,
        nutritionist_id: service.nutritionist_id,
        scheduled_at: scheduled_at
      )

      if !appointment_request.valid?
        # If it failed specifically because the guest already has a pending request -> HTTP 409 (Conflict)
        if appointment_request.errors.of_kind?(:guest, :pending_request_exists)
          return failure(:conflict, [PENDING_REQUEST_MESSAGE])
        end

        # If it failed for any other reason (e.g., date in the past) -> HTTP 422 (Invalid)
        return failure(:invalid, appointment_request.errors.full_messages)
      end

      # Check if the nutritionist already has an accepted appointment overlapping this one.
      if appointment_request.slot_taken?
        return failure(:conflict, [SLOT_TAKEN_MESSAGE])
      end

      appointment_request.save!
      Result.new(status: :created, appointment_request: appointment_request, errors: [])
    end

    # A pending request whose date has passed was never answered and can no longer be.
    # Rejecting it frees the guest from the one-pending-request rule.
    def self.reject_expired_requests(guest)
      now = Time.current
      rejected_count = guest.appointment_requests.pending.past.update_all(status: "rejected", answered_at: now, updated_at: now)
      if rejected_count.positive?
        Rails.logger.info("[Create] rejected expired pending requests guest_id=#{guest.id} count=#{rejected_count}")
      end
    end

    def self.failure(status, errors)
      Result.new(status: status, appointment_request: nil, errors: errors)
    end

    private_class_method :create_request, :reject_expired_requests, :failure
  end
end