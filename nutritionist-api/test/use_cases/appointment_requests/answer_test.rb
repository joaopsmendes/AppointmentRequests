require "test_helper"
require "minitest/mock"

module AppointmentRequests
  class AnswerTest < ActiveSupport::TestCase
    include ActionMailer::TestHelper

    setup do
      # Pedro's pending request with Ana: +21 days, 10:00-11:00
      @request = appointment_requests(:ana_pending_later)
      @slot = @request.scheduled_at
    end

    # --- Accept ---------------------------------------------------------------

    test "accepts a pending request" do
      result = answer(@request, "accepted")

      assert_answered(result, @request, "accepted")
    end

    test "rejects the other pending requests of the nutritionist that overlap the accepted one" do
      overlapping = pending_request(at: @slot + 30.minutes)          # 10:30-11:30
      starts_before = pending_request(at: @slot - 30.minutes)        # 09:30-10:30

      result = answer(@request, "accepted")

      assert_answered(result, @request, "accepted", auto_rejected: [overlapping, starts_before])
      [overlapping, starts_before].each do |request|
        request.reload
        assert request.rejected?
        assert_not_nil request.answered_at
      end
    end

    test "keeps the pending requests that do not lose their slot" do
      adjacent = pending_request(at: @slot + 60.minutes)              # 11:00-12:00
      other_nutritionist = pending_request(at: @slot, service: services(:joao_sports_nutrition))

      result = answer(@request, "accepted")

      assert_answered(result, @request, "accepted", auto_rejected: [])
      assert adjacent.reload.pending?
      assert other_nutritionist.reload.pending?
      assert appointment_requests(:joao_pending).reload.pending?
    end

    test "does not touch requests that were already answered" do
      answer(@request, "accepted")

      assert appointment_requests(:ana_accepted).reload.accepted?
      assert appointment_requests(:ana_rejected).reload.rejected?
    end

    test "refuses to accept a request that overlaps an accepted appointment and keeps it pending" do
      accepted = appointment_requests(:ana_accepted)                   # +22 days, 10:00-11:00
      overlapping = pending_request(at: accepted.scheduled_at + 30.minutes)

      result = answer(overlapping, "accepted")

      assert_failure(result, :conflict, [Answer::OVERLAP_MESSAGE])
      overlapping.reload
      assert overlapping.pending?
      assert_nil overlapping.answered_at
    end

    # --- Reject ---------------------------------------------------------------

    test "rejects a pending request" do
      result = answer(@request, "rejected")

      assert_answered(result, @request, "rejected")
    end

    test "rejecting does not reject other requests, because it frees no slot" do
      overlapping = pending_request(at: @slot + 30.minutes)

      result = answer(@request, "rejected")

      assert_answered(result, @request, "rejected", auto_rejected: [])
      assert overlapping.reload.pending?
    end

    # --- Already answered (conditional UPDATE) --------------------------------

    %w[accepted rejected].each do |answer_status|
      test "returns conflict when #{answer_status == 'accepted' ? 'accepting' : 'rejecting'} a request that was already answered" do
        [appointment_requests(:ana_accepted), appointment_requests(:ana_rejected)].each do |answered|
          previous_status = answered.status
          previous_answered_at = answered.answered_at

          result = answer(answered, answer_status)

          assert_failure(result, :conflict, [Answer::ALREADY_ANSWERED_MESSAGE], "request was #{previous_status}")
          answered.reload
          assert_equal previous_status, answered.status
          assert_equal previous_answered_at, answered.answered_at
        end
      end
    end

    test "returns conflict on the second answer to the same request (double click)" do
      answer(@request, "accepted")

      result = answer(@request, "rejected")

      assert_failure(result, :conflict, [Answer::ALREADY_ANSWERED_MESSAGE])
      assert @request.reload.accepted?
    end

    # --- Emails, sent only after the commit ---------------------------------

    test "emails the accepted guest and every auto-rejected guest" do
      overlapping = pending_request(at: @slot + 30.minutes)

      assert_enqueued_emails 2 do
        answer(@request, "accepted")
      end
      assert_enqueued_email_with GuestMailer, :answered, args: [@request]
      assert_enqueued_email_with GuestMailer, :answered, args: [overlapping]
    end

    test "emails the guest of a rejected request" do
      assert_enqueued_emails 1 do
        answer(@request, "rejected")
      end
      assert_enqueued_email_with GuestMailer, :answered, args: [@request]
    end

    test "sends no email when the answer fails" do
      accepted = appointment_requests(:ana_accepted)
      overlapping = pending_request(at: accepted.scheduled_at + 30.minutes)

      assert_no_enqueued_emails do
        answer(overlapping, "accepted")                   # overlap
        answer(accepted, "rejected")                      # already answered
        answer(@request, "maybe")                         # invalid status
        Answer.call(id: 0, status: "accepted")            # not found
      end
    end

    # --- Invalid input ----------------------------------------------------------

    test "refuses a status other than accepted or rejected" do
      [nil, "", "pending", "cancelled"].each do |status|
        result = answer(@request, status)

        assert_failure(result, :invalid, ["Status must be one of: accepted, rejected"], "status=#{status.inspect}")
      end
      assert @request.reload.pending?
    end

    test "refuses to accept a request whose date has already passed" do
      @request.update_columns(scheduled_at: 1.hour.ago, ends_at: 1.hour.ago + 60.minutes)

      result = answer(@request, "accepted")

      assert_failure(result, :invalid, [Answer::PAST_MESSAGE])
      assert @request.reload.pending?
    end

    test "still allows rejecting a request whose date has already passed" do
      @request.update_columns(scheduled_at: 1.hour.ago, ends_at: 1.hour.ago + 60.minutes)

      assert_answered(answer(@request, "rejected"), @request, "rejected")
    end

    test "returns not_found for an unknown request" do
      result = Answer.call(id: 0, status: "accepted")

      assert_failure(result, :not_found, ["Appointment request not found"])
    end

    # --- Deadlock retry -----------------------------------------------------------

    test "retries after a deadlock and returns the result of the retry" do
      original_answer = Answer.method(:answer)
      calls = 0
      deadlock_once = lambda do |*args|
        calls += 1
        raise ActiveRecord::Deadlocked, "deadlock detected" if calls == 1

        original_answer.call(*args)
      end

      result = Answer.stub(:answer, deadlock_once) { answer(@request, "accepted") }

      assert_equal 2, calls
      assert_answered(result, @request, "accepted")
    end

    test "gives up after #{Answer::MAX_ATTEMPTS} deadlocks" do
      calls = 0
      always_deadlock = lambda do |*|
        calls += 1
        raise ActiveRecord::Deadlocked, "deadlock detected"
      end

      Answer.stub(:answer, always_deadlock) do
        assert_raises(ActiveRecord::Deadlocked) { answer(@request, "accepted") }
      end
      assert_equal Answer::MAX_ATTEMPTS, calls
    end

    private

    def answer(request, status)
      Answer.call(id: request.id, status: status)
    end

    # A pending request for a new guest (each guest can only have one pending request).
    def pending_request(at:, service: services(:ana_first_appointment))
      guest = Guest.create!(name: "Guest", email: "guest-#{SecureRandom.hex(4)}@example.com")
      AppointmentRequest.create!(guest: guest, service: service, nutritionist_id: service.nutritionist_id, scheduled_at: at)
    end

    # Checks the whole success Result and the answered request, in memory and in the database.
    def assert_answered(result, request, status, auto_rejected: [])
      assert_equal :ok, result.status
      assert result.success?
      assert_empty result.errors
      assert_equal auto_rejected.map(&:id).sort, result.auto_rejected_ids.sort

      assert_equal request.id, result.appointment_request.id
      [result.appointment_request, AppointmentRequest.find(request.id)].each do |record|
        assert_equal status, record.status
        assert_in_delta Time.current, record.answered_at, 5.seconds
      end
    end

    # Checks the whole failure Result: the status, the exact errors, no request and nothing auto-rejected.
    def assert_failure(result, status, errors, message = nil)
      assert_equal status, result.status, message
      refute result.success?, message
      assert_nil result.appointment_request, message
      assert_empty result.auto_rejected_ids, message
      assert_equal errors, result.errors, message
    end
  end
end
