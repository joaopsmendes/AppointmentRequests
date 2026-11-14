class NotificationService
  def self.notify(appointment_request)
    GuestMailer.answered(appointment_request).deliver_later
  end
end