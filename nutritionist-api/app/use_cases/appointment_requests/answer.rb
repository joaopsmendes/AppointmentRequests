module AppointmentRequests
  class Answer
    Result = Struct.new(:status, :appointment_request, :auto_rejected_ids, :errors, keyword_init: true) do
      def success?
        status == :ok
      end
    end

    ANSWERS = %w[accepted rejected].freeze
    MAX_ATTEMPTS = 3
    ALREADY_ANSWERED_MESSAGE = "This appointment request has already been answered".freeze
    OVERLAP_MESSAGE = "Cannot accept: it overlaps an already accepted appointment".freeze

    def self.call(id:, status:)
      unless ANSWERS.include?(status)
        return failure(:invalid, ["Status must be one of: #{ANSWERS.join(', ')}"])
      end

      appointment_request = AppointmentRequest.find_by(id: id)
      return failure(:not_found, ["Appointment request not found"]) unless appointment_request

      attempts = 0
      begin
        attempts += 1
        answer(appointment_request, status)
      rescue ActiveRecord::Deadlocked
        # Two overlapping accepts at the same time can deadlock.
        # PostgreSQL cancels one, and retrying it returns the correct 409.
        retry if attempts < MAX_ATTEMPTS
        raise
      end
    end

    def self.answer(appointment_request, status)
      answered = false
      auto_rejected_ids = []

      begin
        ActiveRecord::Base.transaction do
          answered = appointment_request.answer!(status)

          # Already answered (double click or two tabs): stop here, nothing else to do.
          if !answered
            raise ActiveRecord::Rollback
          end

          # reject the pending requests that lost this time slot.
          auto_rejected_ids = reject_conflicting_requests(appointment_request) if appointment_request.accepted?
        end

        if !answered
          return failure(:conflict, [ALREADY_ANSWERED_MESSAGE])
        end

        # After the commit: an email cannot be undone by a rollback.
        notify_guests([appointment_request.id] + auto_rejected_ids)

        Result.new(
          status: :ok,
          appointment_request: appointment_request,
          auto_rejected_ids: auto_rejected_ids,
          errors: []
        )
      rescue ActiveRecord::StatementInvalid => e
        # The exclusion constraint refused the accept: it overlaps an accepted appointment.
        if e.cause.is_a?(PG::ExclusionViolation)
          return failure(:conflict, [OVERLAP_MESSAGE])
        end
        # Any other database error (including a deadlock) goes up to the caller.
        raise
      end
    end

    # Concurrency Guarantee
    # Pending requests left without a slot by the accepted one:
    # - the same guest at the same date and time (challenge rule);
    # - any request of the same nutritionist overlapping the accepted interval.
    def self.reject_conflicting_requests(accepted)
      other_pending = AppointmentRequest.pending.where.not(id: accepted.id)
      same_guest_same_time = other_pending.where(guest_id: accepted.guest_id, scheduled_at: accepted.scheduled_at)
      same_nutritionist_overlapping = other_pending.where(nutritionist_id: accepted.nutritionist_id)
                                                    .overlapping(accepted.scheduled_at, accepted.ends_at)

      # FOR UPDATE: the rows cannot be answered by someone else until this transaction ends.
      ids_to_reject = same_guest_same_time.or(same_nutritionist_overlapping).lock.pluck(:id)
      return [] if ids_to_reject.empty?

      now = Time.current
      AppointmentRequest.where(id: ids_to_reject).update_all(status: "rejected", answered_at: now, updated_at: now)
      ids_to_reject
    end

    def self.notify_guests(ids)
      AppointmentRequest.where(id: ids).each do |appointment_request|
        NotificationService.notify(appointment_request)
      end
    end

    def self.failure(status, errors)
      Result.new(status: status, appointment_request: nil, auto_rejected_ids: [], errors: errors)
    end

    private_class_method :answer, :reject_conflicting_requests, :notify_guests, :failure
  end
end