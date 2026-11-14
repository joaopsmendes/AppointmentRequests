import { request } from './client'

// GET /api/nutritionists/:id/appointment_requests?status=&page=
export function listAppointmentRequests(nutritionistId, { status = 'pending', page = 1 } = {}) {
  const params = new URLSearchParams({ status, page })
  return request(`/api/nutritionists/${nutritionistId}/appointment_requests?${params}`)
}

// POST /api/appointment_requests
export function createAppointmentRequest({ name, email, serviceId, scheduledAt }) {
  return request('/api/appointment_requests', {
    method: 'POST',
    body: JSON.stringify({
      appointment_request: { name, email, service_id: serviceId, scheduled_at: scheduledAt },
    }),
  })
}

// PATCH /api/appointment_requests/:id with { status: "accepted" | "rejected" }
export function answerAppointmentRequest(id, status) {
  return request(`/api/appointment_requests/${id}`, {
    method: 'PATCH',
    body: JSON.stringify({ status }),
  })
}
