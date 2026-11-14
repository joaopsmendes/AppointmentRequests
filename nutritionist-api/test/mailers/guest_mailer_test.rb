require "test_helper"

class GuestMailerTest < ActionMailer::TestCase
  test "tells the guest the request was accepted, with the appointment details" do
    request = appointment_requests(:ana_accepted) # Rui with Ana, First appointment in Lisboa

    mail = GuestMailer.answered(request)

    assert_equal ["rui@example.com"], mail.to
    assert_equal ["from@example.com"], mail.from
    assert_equal "Your appointment with Ana Lima was accepted", mail.subject
    assert_email_body mail, [
      "Hello Rui Matos,",
      "Your appointment request was accepted.",
      "Nutritionist: Ana Lima",
      "Service: First appointment (Lisboa)",
      "Date: #{request.scheduled_at.strftime('%d/%m/%Y %H:%M')}"
    ]
    refute_includes mail.body.to_s, "rejected"
  end

  test "tells the guest the request was rejected and that another time can be requested" do
    request = appointment_requests(:ana_rejected) # Joana with Ana

    mail = GuestMailer.answered(request)

    assert_equal ["joana@example.com"], mail.to
    assert_equal "Your appointment request with Ana Lima was rejected", mail.subject
    assert_email_body mail, [
      "Hello Joana Reis,",
      "Unfortunately, your appointment request was rejected. You can request another date and time.",
      "Nutritionist: Ana Lima",
      "Date: #{request.scheduled_at.strftime('%d/%m/%Y %H:%M')}"
    ]
    refute_includes mail.body.to_s, "was accepted"
  end

  private

  def assert_email_body(mail, expected_lines)
    body = mail.body.to_s
    expected_lines.each { |line| assert_includes body, line }
  end
end
