require "test_helper"

module AppointmentRequests
  class ListAppointmentRequestsTest < ActiveSupport::TestCase
    setup do
      @ana = nutritionists(:ana)
    end

    # --- Filtering by status -------------------------------------------------

    test "lists the pending requests by default, soonest first" do
      result = list

      assert_listed(result, [appointment_requests(:ana_pending_sooner), appointment_requests(:ana_pending_later)])
    end

    test "treats a blank status as pending" do
      assert_listed(list(status: ""), [appointment_requests(:ana_pending_sooner), appointment_requests(:ana_pending_later)])
    end

    test "lists the accepted requests when asked" do
      assert_listed(list(status: "accepted"), [appointment_requests(:ana_accepted)], status: "accepted")
    end

    test "lists the rejected requests when asked" do
      assert_listed(list(status: "rejected"), [appointment_requests(:ana_rejected)], status: "rejected")
    end

    # --- Past requests -----------------------------------------------------------

    test "hides pending requests whose date has already passed" do
      appointment_requests(:ana_pending_sooner).update_columns(scheduled_at: 1.day.ago, ends_at: 1.day.ago + 30.minutes)

      assert_listed(list, [appointment_requests(:ana_pending_later)])
    end

    test "still lists past answered requests in the history" do
      appointment_requests(:ana_accepted).update_columns(scheduled_at: 1.day.ago, ends_at: 1.day.ago + 60.minutes)

      assert_listed(list(status: "accepted"), [appointment_requests(:ana_accepted)], status: "accepted")
    end

    # --- Scope ----------------------------------------------------------------

    test "only lists the requests of the given nutritionist" do
      result = list(nutritionist: nutritionists(:joao))

      assert_listed(result, [appointment_requests(:joao_pending)], nutritionist: nutritionists(:joao))
    end

    test "returns an empty list for a nutritionist without requests" do
      result = list(nutritionist: nutritionists(:rita))

      assert_listed(result, [], nutritionist: nutritionists(:rita))
      assert_equal 0, result.total_count
      assert_equal 0, result.total_pages
    end

    test "preloads the guest and the service to avoid N+1 queries" do
      list.records.each do |request|
        assert request.association(:guest).loaded?
        assert request.association(:service).loaded?
      end
    end

    # --- Ordering and pagination ---------------------------------------------

    test "breaks ties on the same date by id, so pagination is stable" do
      # Same start as ana_pending_sooner, one per page: without the tie-break by id
      # PostgreSQL could return the same request on both pages and skip the other.
      sooner = appointment_requests(:ana_pending_sooner)
      twin = AppointmentRequest.create!(guest: guests(:maria), service: sooner.service,
                                        nutritionist: @ana, scheduled_at: sooner.scheduled_at)

      first_page = list(per_page: 1, page: 1).records.to_a
      second_page = list(per_page: 1, page: 2).records.to_a

      assert_equal [sooner.id, twin.id].sort, (first_page + second_page).map(&:id)
    end

    test "paginates the results" do
      result = list(page: 2, per_page: 1)

      assert_listed(result, [appointment_requests(:ana_pending_later)])
      assert_equal 2, result.page
      assert_equal 1, result.per_page
      assert_equal 2, result.total_count
      assert_equal 2, result.total_pages
    end

    test "caps per_page at 25" do
      assert_equal 25, list(per_page: 1000).per_page
    end

    test "falls back to the first page for invalid page values" do
      [nil, 0, -1, "abc"].each do |page|
        assert_equal 1, list(page: page).page, "page=#{page.inspect}"
      end
    end

    test "falls back to the default per_page for invalid values" do
      # Params arrive as strings, so "0" is what ?per_page=0 sends.
      [nil, "", "abc", -5, 0, "0"].each do |per_page|
        result = list(per_page: per_page)
        assert_equal 25, result.per_page, "per_page=#{per_page.inspect}"
      rescue StandardError => e
        flunk "per_page=#{per_page.inspect} raised #{e.class}: #{e.message}"
      end
    end

    # --- Errors ---------------------------------------------------------------

    test "returns not_found for an unknown nutritionist" do
      result = ListAppointmentRequests.call(nutritionist_id: 0)

      assert_failure(result, :not_found, ["Nutritionist not found"])
    end

    test "returns invalid for an unknown status" do
      result = list(status: "cancelled")

      assert_failure(result, :invalid, ["Status must be one of: pending, accepted, rejected"])
    end

    private

    def list(nutritionist: @ana, status: nil, page: nil, per_page: nil)
      ListAppointmentRequests.call(nutritionist_id: nutritionist.id, status: status, page: page, per_page: per_page)
    end

    # Checks the whole success Result: the exact requests in the exact order,
    # all from the given nutritionist and with the given status.
    def assert_listed(result, expected_requests, nutritionist: @ana, status: "pending")
      assert_equal :ok, result.status
      assert result.success?
      assert_empty result.errors

      assert_equal expected_requests.map(&:id), result.records.map(&:id)
      result.records.each do |request|
        assert_equal nutritionist.id, request.nutritionist_id
        assert_equal status, request.status
      end
    end

    # Checks the whole failure Result: the status, the exact errors and no records.
    def assert_failure(result, status, errors)
      assert_equal status, result.status
      refute result.success?
      assert_empty result.records
      assert_equal errors, result.errors
    end
  end
end
