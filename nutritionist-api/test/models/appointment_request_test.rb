require "test_helper"

# Most rules of this model are tested through the use cases (Create, Answer, List).
# These are the ones no use case can reach.
class AppointmentRequestTest < ActiveSupport::TestCase
  test "requires the service to belong to the nutritionist" do
    request = AppointmentRequest.new(
      guest: guests(:maria),
      service: services(:ana_first_appointment),
      nutritionist: nutritionists(:joao),
      scheduled_at: 3.days.from_now
    )

    assert_not request.valid?
    assert_includes request.errors[:service], "does not belong to the selected nutritionist"
  end

  test "an unknown status is a validation error, not an exception" do
    request = appointment_requests(:ana_pending_later)

    request.status = "cancelled"

    assert_not request.valid?
    assert request.errors.of_kind?(:status, :inclusion)
  end
end
