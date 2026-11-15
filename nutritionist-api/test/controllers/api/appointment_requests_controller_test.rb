require "test_helper"

module Api
  class AppointmentRequestsControllerTest < ActionDispatch::IntegrationTest
    include ActionMailer::TestHelper

    REQUEST_KEYS = %w[answered_at ends_at guest id nutritionist_id scheduled_at service status].freeze

    setup do
      @ana = nutritionists(:ana)
      @service = services(:ana_first_appointment) # 60 minutes
      @slot = 5.days.from_now.change(hour: 15)
    end

    # --- GET /api/nutritionists/:nutritionist_id/appointment_requests -----------------

    test "index lists the pending requests of the nutritionist, with the pagination" do
      get "/api/nutritionists/#{@ana.id}/appointment_requests"

      assert_response :ok
      body = response.parsed_body
      expected = [appointment_requests(:ana_pending_sooner), appointment_requests(:ana_pending_later)]
      assert_equal expected.map(&:id), body["data"].map { |r| r["id"] }
      assert_equal({ "page" => 1, "per_page" => 25, "total_count" => 2, "total_pages" => 1 }, body["meta"])
    end

    test "index serializes each request with its guest and service" do
      get "/api/nutritionists/#{@ana.id}/appointment_requests", params: { status: "accepted" }

      assert_response :ok
      request = appointment_requests(:ana_accepted)
      item = response.parsed_body["data"].sole

      assert_equal REQUEST_KEYS, item.keys.sort
      assert_equal request.id, item["id"]
      assert_equal "accepted", item["status"]
      assert_equal request.scheduled_at.iso8601, item["scheduled_at"]
      assert_equal request.ends_at.iso8601, item["ends_at"]
      assert_equal request.answered_at.iso8601, item["answered_at"]
      assert_equal @ana.id, item["nutritionist_id"]
      assert_equal({ "id" => @service.id, "description" => "First appointment" }, item["service"])
      assert_equal({ "name" => "Rui Matos", "email" => "rui@example.com" }, item["guest"])
    end

    test "index returns 404 for an unknown nutritionist" do
      get "/api/nutritionists/0/appointment_requests"

      assert_response :not_found
      assert_equal({ "errors" => ["Nutritionist not found"] }, response.parsed_body)
    end

    test "index returns 422 for an unknown status" do
      get "/api/nutritionists/#{@ana.id}/appointment_requests", params: { status: "cancelled" }

      assert_response :unprocessable_entity
      assert_equal({ "errors" => ["Status must be one of: pending, accepted, rejected"] }, response.parsed_body)
    end

    # --- POST /api/appointment_requests --------------------------------------------------

    test "create returns 201 with the new pending request" do
      assert_difference -> { AppointmentRequest.count }, 1 do
        post_request
      end

      assert_response :created
      body = response.parsed_body
      assert_equal REQUEST_KEYS, body.keys.sort
      assert_equal "pending", body["status"]
      assert_nil body["answered_at"]
      assert_equal @slot.iso8601, body["scheduled_at"]
      assert_equal (@slot + 60.minutes).iso8601, body["ends_at"]
      assert_equal({ "name" => "New Guest", "email" => "new@example.com" }, body["guest"])
    end

    test "create ignores fields the client is not allowed to set" do
      post_request(status: "accepted", ends_at: (@slot + 5.minutes).iso8601, nutritionist_id: nutritionists(:joao).id)

      assert_response :created
      request = AppointmentRequest.find(response.parsed_body["id"])
      assert request.pending?
      assert_equal @slot + 60.minutes, request.ends_at
      assert_equal @ana.id, request.nutritionist_id
    end

    test "create returns 400 when the appointment_request key is missing" do
      post "/api/appointment_requests", params: { name: "New Guest" }, as: :json

      assert_response :bad_request
      assert_equal 1, response.parsed_body["errors"].size
      assert_match "appointment_request", response.parsed_body["errors"].first
    end

    test "create returns 409 when the guest already has a pending request" do
      post_request(email: "pedro@example.com")

      assert_response :conflict
      assert_equal({ "errors" => [AppointmentRequests::Create::PENDING_REQUEST_MESSAGE] }, response.parsed_body)
    end

    test "create returns 422 for a date in the past" do
      post_request(scheduled_at: 1.day.ago.iso8601)

      assert_response :unprocessable_entity
      assert_equal({ "errors" => ["Scheduled at must be in the future"] }, response.parsed_body)
    end

    test "create returns 404 for an unknown service" do
      post_request(service_id: 0)

      assert_response :not_found
      assert_equal({ "errors" => ["Service not found"] }, response.parsed_body)
    end

    # --- PATCH /api/appointment_requests/:id ------------------------------------------

    test "update accepts a request, returns it with the auto-rejected ids and emails the guest" do
      request = appointment_requests(:ana_pending_later)

      assert_enqueued_emails 1 do
        patch "/api/appointment_requests/#{request.id}", params: { status: "accepted" }, as: :json
      end

      assert_response :ok
      body = response.parsed_body
      assert_equal %w[appointment_request auto_rejected_ids], body.keys.sort
      assert_equal request.id, body["appointment_request"]["id"]
      assert_equal "accepted", body["appointment_request"]["status"]
      assert_not_nil body["appointment_request"]["answered_at"]
      assert_equal [], body["auto_rejected_ids"]
    end

    test "update rejects a request" do
      request = appointment_requests(:ana_pending_later)

      patch "/api/appointment_requests/#{request.id}", params: { status: "rejected" }, as: :json

      assert_response :ok
      assert_equal "rejected", response.parsed_body["appointment_request"]["status"]
    end

    test "update returns 400 when the status is missing" do
      patch "/api/appointment_requests/#{appointment_requests(:ana_pending_later).id}", params: {}, as: :json

      assert_response :bad_request
      assert_match "status", response.parsed_body["errors"].first
    end

    test "update returns 422 for an invalid status" do
      patch "/api/appointment_requests/#{appointment_requests(:ana_pending_later).id}", params: { status: "pending" }, as: :json

      assert_response :unprocessable_entity
      assert_equal({ "errors" => ["Status must be one of: accepted, rejected"] }, response.parsed_body)
    end

    test "update returns 404 for an unknown request" do
      patch "/api/appointment_requests/0", params: { status: "accepted" }, as: :json

      assert_response :not_found
      assert_equal({ "errors" => ["Appointment request not found"] }, response.parsed_body)
    end

    test "update returns 409 for a request that was already answered" do
      patch "/api/appointment_requests/#{appointment_requests(:ana_accepted).id}", params: { status: "rejected" }, as: :json

      assert_response :conflict
      assert_equal({ "errors" => [AppointmentRequests::Answer::ALREADY_ANSWERED_MESSAGE] }, response.parsed_body)
    end

    private

    def post_request(**overrides)
      attributes = { name: "New Guest", email: "new@example.com", service_id: @service.id,
                     scheduled_at: @slot.iso8601 }.merge(overrides)
      post "/api/appointment_requests", params: { appointment_request: attributes }, as: :json
    end
  end
end
