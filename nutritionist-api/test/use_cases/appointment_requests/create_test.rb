require "test_helper"

module AppointmentRequests
  class CreateTest < ActiveSupport::TestCase
    include ActionMailer::TestHelper

    setup do
      # 10:00-11:00 with Ana's 60-minute first appointment
      @slot = 3.days.from_now.change(hour: 10)
      @service = services(:ana_first_appointment)
    end

    # --- Success -------------------------------------------------------------

    test "creates a pending request and a new guest" do
      result = nil

      assert_difference -> { Guest.count } => 1, -> { AppointmentRequest.count } => 1 do
        result = create(name: "New Guest", email: "new@example.com")
      end

      request = assert_created(result, guest_email: "new@example.com")
      assert_equal "New Guest", request.guest.name
    end

    test "computes ends_at from the service duration" do
      request = assert_created(create, guest_email: "guest@example.com")

      assert_equal @slot + 60.minutes, request.ends_at
    end

    test "takes the nutritionist from the service, not from the client" do
      request = assert_created(create, guest_email: "guest@example.com")

      assert_equal nutritionists(:ana).id, request.nutritionist_id
    end

    test "reuses an existing guest by email, ignoring case and spaces, and keeps the original name" do
      result = nil

      assert_no_difference -> { Guest.count } do
        result = create(name: "Someone Else", email: "  MARIA@Example.com ")
      end

      request = assert_created(result, guest_email: "maria@example.com")
      assert_equal guests(:maria), request.guest
      assert_equal "Maria Santos", guests(:maria).reload.name
    end

    # --- One pending request per guest ---------------------------------------

    test "refuses a second pending request from the same guest" do
      create(email: "maria@example.com")
      result = nil

      assert_no_difference -> { AppointmentRequest.count } do
        result = create(email: "maria@example.com", scheduled_at: @slot + 1.day)
      end

      assert_failure(result, :conflict, [Create::PENDING_REQUEST_MESSAGE])
    end

    # Only a pending request blocks a new one: answered requests do not count.
    %w[accepted rejected].each do |previous_status|
      test "allows a new request when the guest's previous request was #{previous_status}" do
        create(email: "maria@example.com").appointment_request.update!(status: previous_status)
        result = nil

        assert_difference -> { AppointmentRequest.count }, 1 do
          result = create(email: "maria@example.com", scheduled_at: @slot + 1.day)
        end

        assert_created(result, guest_email: "maria@example.com", scheduled_at: @slot + 1.day)
        assert_equal [previous_status, "pending"], guests(:maria).appointment_requests.order(:scheduled_at).pluck(:status)
      end
    end

    # --- Past pending requests -------------------------------------------------

    test "rejects the guest's past pending request, without an email, so a new one can be made" do
      expired = past_pending_request(email: "maria@example.com")
      result = nil

      assert_no_enqueued_emails do
        result = create(email: "maria@example.com", scheduled_at: @slot + 1.day)
      end

      assert_created(result, guest_email: "maria@example.com", scheduled_at: @slot + 1.day)
      expired.reload
      assert_equal "rejected", expired.status
      assert_in_delta Time.current, expired.answered_at, 5.seconds
    end

    test "does not touch the past pending requests of other guests" do
      other_guest_request = past_pending_request(email: "other@example.com")

      assert_created(create(email: "maria@example.com"), guest_email: "maria@example.com")
      assert other_guest_request.reload.pending?
    end

    # --- Accepted slots --------------------------------------------------------

    test "refuses a slot overlapping an accepted appointment of the same nutritionist" do
      accept(create(email: "first@example.com"))
      result = nil

      assert_no_difference -> { AppointmentRequest.count } do
        result = create(email: "second@example.com", scheduled_at: @slot + 30.minutes)
      end

      assert_failure(result, :conflict, [Create::SLOT_TAKEN_MESSAGE])
    end

    test "refuses exactly the same slot as an accepted appointment" do
      accept(create(email: "first@example.com")) # 10:00-11:00

      result = create(email: "second@example.com") # 10:00-11:00

      assert_failure(result, :conflict, [Create::SLOT_TAKEN_MESSAGE])
    end

    test "refuses a slot that starts before and ends during an accepted appointment" do
      accept(create(email: "first@example.com")) # 10:00-11:00

      result = create(email: "second@example.com", scheduled_at: @slot - 30.minutes) # 09:30-10:30

      assert_failure(result, :conflict, [Create::SLOT_TAKEN_MESSAGE])
    end

    test "allows a slot right before an accepted appointment (half-open interval)" do
      accept(create(email: "first@example.com")) # 10:00-11:00

      result = create(email: "second@example.com", scheduled_at: @slot - 60.minutes) # 09:00-10:00

      assert_created(result, guest_email: "second@example.com", scheduled_at: @slot - 60.minutes)
    end

    test "allows a slot right after an accepted appointment (half-open interval)" do
      accept(create(email: "first@example.com")) # 10:00-11:00

      result = create(email: "second@example.com", scheduled_at: @slot + 60.minutes) # 11:00-12:00

      assert_created(result, guest_email: "second@example.com", scheduled_at: @slot + 60.minutes)
    end

    test "allows the same time with another nutritionist" do
      accept(create(email: "first@example.com"))
      joao_service = services(:joao_sports_nutrition)

      result = create(email: "second@example.com", service: joao_service)

      assert_created(result, guest_email: "second@example.com", service: joao_service)
    end

    test "allows a slot overlapping a pending request, because pending does not reserve it" do
      create(email: "first@example.com")

      result = create(email: "second@example.com", scheduled_at: @slot + 30.minutes)

      assert_created(result, guest_email: "second@example.com", scheduled_at: @slot + 30.minutes)
    end

    # --- Invalid input --------------------------------------------------------

    test "refuses a date in the past" do
      result = create(scheduled_at: 1.hour.ago)

      assert_failure(result, :invalid, ["Scheduled at must be in the future"])
    end

    test "refuses a missing or unparseable date" do
      [nil, "", "not a date"].each do |scheduled_at|
        result = create(scheduled_at: scheduled_at)

        assert_failure(result, :invalid, ["Scheduled at can't be blank"], "scheduled_at=#{scheduled_at.inspect}")
      end
    end

    test "refuses an invalid email" do
      result = create(email: "not-an-email")

      assert_failure(result, :invalid, ["Email is invalid"])
    end

    test "refuses a new guest without a name" do
      result = create(name: "  ", email: "new@example.com")

      assert_failure(result, :invalid, ["Name can't be blank"])
    end

    test "returns not_found for an unknown service" do
      result = create(service: Service.new(id: 0))

      assert_failure(result, :not_found, ["Service not found"])
    end

    # --- Transaction ------------------------------------------------------------

    test "does not keep the new guest when the request fails" do
      assert_no_difference -> { Guest.count } do
        create(email: "new@example.com", scheduled_at: 1.hour.ago)
      end
    end

    private

    def create(name: "Test Guest", email: "guest@example.com", service: @service, scheduled_at: @slot)
      Create.call(name: name, email: email, service_id: service.id, scheduled_at: scheduled_at)
    end

    # A pending request whose date has already passed (moved to the past after being created,
    # since the model does not allow creating it in the past).
    def past_pending_request(email:)
      request = create(email: email).appointment_request
      request.update_columns(scheduled_at: 1.day.ago, ends_at: 1.day.ago + 60.minutes)
      request
    end

    def accept(result)
      result.appointment_request.update!(status: :accepted)
    end

    # Checks the whole success Result and every field of the returned request
    def assert_created(result, guest_email:, service: @service, scheduled_at: @slot)
      assert_equal :created, result.status
      assert result.success?
      assert_empty result.errors

      request = result.appointment_request
      assert request.persisted?, "the request should be saved"

      [request, AppointmentRequest.find(request.id)].each do |record|
        assert_equal "pending", record.status
        assert_equal guest_email, record.guest.email
        assert_equal service.id, record.service_id
        assert_equal service.nutritionist_id, record.nutritionist_id
        assert_equal scheduled_at, record.scheduled_at
        assert_equal scheduled_at + service.duration_minutes.minutes, record.ends_at
        assert_nil record.answered_at
      end

      request
    end

    # Checks the whole failure Result: the status, the exact errors and no request.
    def assert_failure(result, status, errors, message = nil)
      assert_equal status, result.status, message
      refute result.success?, message
      assert_nil result.appointment_request, message
      assert_equal errors, result.errors, message
    end
  end
end
