class GuestMailer < ApplicationMailer
  def answered(appointment_request)
    @appointment_request = appointment_request
    @guest = appointment_request.guest
    @nutritionist = appointment_request.nutritionist
    @service = appointment_request.service

    subject = if appointment_request.accepted?
                "Your appointment with #{@nutritionist.name} was accepted"
              else
                "Your appointment request with #{@nutritionist.name} was rejected"
              end

    mail(to: @guest.email, subject: subject)
  end
end
