class AppointmentRequestSerializer
  def self.render(appointment_request)
    {
      id: appointment_request.id,
      status: appointment_request.status,
      scheduled_at: appointment_request.scheduled_at.iso8601,
      ends_at: appointment_request.ends_at.iso8601,
      answered_at: appointment_request.answered_at&.iso8601,
      nutritionist_id: appointment_request.nutritionist_id,
      service: {
        id: appointment_request.service.id,
        description: appointment_request.service.description
      },
      guest: {
        name: appointment_request.guest.name,
        email: appointment_request.guest.email
      }
    }
  end
end
