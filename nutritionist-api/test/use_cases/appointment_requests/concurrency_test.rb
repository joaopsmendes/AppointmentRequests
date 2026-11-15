require "test_helper"

module AppointmentRequests
  # Runs two use case calls at the same time, each in its own thread and database connection,
  # to check the guarantees that only show up under real concurrent transactions.
  #
  # Transactional tests are off: each thread commits for real, so it can see (and race with)
  # the other one. These tests never modify fixtures and delete what they create in teardown.
  class ConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    EMAIL_DOMAIN = "concurrency.test".freeze

    setup do
      # Far from the fixtures (20+ days) and from the Create tests (3 days).
      @slot = 40.days.from_now.change(hour: 10)
      @service = services(:ana_first_appointment) # 60 minutes
    end

    teardown do
      guests = Guest.where("email LIKE ?", "%@#{EMAIL_DOMAIN}")
      AppointmentRequest.where(guest: guests).delete_all
      guests.delete_all
    end

    test "two simultaneous requests from the same new guest create a single pending request" do
      email = "same-guest@#{EMAIL_DOMAIN}"

      statuses = run_concurrently(
        -> { create_request(email: email, scheduled_at: @slot) },
        -> { create_request(email: email, scheduled_at: @slot + 1.day) }
      )

      assert_equal %i[conflict created], statuses.sort
      guest = Guest.find_by!(email: email)
      assert_equal 1, Guest.where(email: email).count
      assert_equal 1, guest.appointment_requests.pending.count
    end

    test "two simultaneous accepts of overlapping requests leave a single accepted appointment" do
      first = pending_request("first", at: @slot)                    # 10:00-11:00
      second = pending_request("second", at: @slot + 30.minutes)     # 10:30-11:30

      statuses = run_concurrently(
        -> { Answer.call(id: first.id, status: "accepted").status },
        -> { Answer.call(id: second.id, status: "accepted").status }
      )

      assert_equal %i[conflict ok], statuses.sort
      # The winner is accepted; the loser was auto-rejected by it.
      assert_equal %w[accepted rejected], [first.reload.status, second.reload.status].sort
    end

    test "two simultaneous answers to the same request: only one of them wins" do
      request = pending_request("double-click", at: @slot)

      results = run_concurrently(
        -> { Answer.call(id: request.id, status: "accepted") },
        -> { Answer.call(id: request.id, status: "rejected") }
      )

      assert_equal %i[conflict ok], results.map(&:status).sort
      winner = results.find(&:success?)
      request.reload
      assert_equal winner.appointment_request.status, request.status
      assert_not_nil request.answered_at
    end

    test "a request created while an overlapping one is being accepted never stays pending" do
      accepted = pending_request("accepted", at: @slot)    # 10:00-11:00
      email = "newcomer@#{EMAIL_DOMAIN}"

      answer_status, create_status = run_concurrently(
        -> { Answer.call(id: accepted.id, status: "accepted").status },
        -> { create_request(email: email, scheduled_at: @slot + 30.minutes) } # 10:30-11:30
      )

      assert_equal :ok, answer_status
      assert_equal "accepted", accepted.reload.status
      # Either the request was refused (409) or it was created and then auto-rejected by the accept.
      assert_includes %i[conflict created], create_status
      assert_not AppointmentRequest.pending.joins(:guest).exists?(guests: { email: email })
    end

    private

    # Starts every block in its own thread and connection, releases them together
    # with a barrier so they really overlap, and returns their results in order.
    def run_concurrently(*blocks)
      barrier = Concurrent::CyclicBarrier.new(blocks.size)

      threads = blocks.map do |block|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            barrier.wait(5)
            block.call
          end
        end
      end

      threads.map(&:value) # re-raises any exception from a thread
    end

    def create_request(email:, scheduled_at:)
      Create.call(name: "Concurrent Guest", email: email, service_id: @service.id, scheduled_at: scheduled_at).status
    end

    # A committed pending request for a new guest of this test.
    def pending_request(name, at:)
      guest = Guest.create!(name: name, email: "#{name}@#{EMAIL_DOMAIN}")
      AppointmentRequest.create!(guest: guest, service: @service, nutritionist_id: @service.nutritionist_id, scheduled_at: at)
    end
  end
end
