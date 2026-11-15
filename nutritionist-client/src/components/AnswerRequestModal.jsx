import { useState } from 'react'
import { answerAppointmentRequest } from '../api/appointmentRequests'
import { ApiError } from '../api/client'
import { formatDate, formatTime } from '../utils/dates'
import Modal from './Modal'

function AnswerRequestModal({ appointmentRequest, onClose, onAnswered, onOutdated }) {
  const [submitting, setSubmitting] = useState(null)
  const [errors, setErrors] = useState([])

  const { guest, service, scheduled_at: scheduledAt } = appointmentRequest

  async function answer(status) {
    setSubmitting(status)
    setErrors([])

    try {
      const response = await answerAppointmentRequest(appointmentRequest.id, status)
      onAnswered(response)
    } catch (error) {
      const apiMessages = error instanceof ApiError ? error.errors : []
      setErrors(apiMessages.length > 0 ? apiMessages : ['Something went wrong. Please try again.'])
      
      if (error instanceof ApiError && error.status === 409) onOutdated()
      setSubmitting(null)
    }
  }

  return (
    <Modal title="Answer request" onClose={onClose}>
      <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm">
        <dt className="text-slate-500">Guest</dt>
        <dd className="text-slate-800">{guest.name}</dd>
        <dt className="text-slate-500">Email</dt>
        <dd className="text-slate-800">{guest.email}</dd>
        <dt className="text-slate-500">Service</dt>
        <dd className="text-slate-800">{service.description}</dd>
        <dt className="text-slate-500">When</dt>
        <dd className="text-slate-800">
          {formatDate(scheduledAt)}, {formatTime(scheduledAt)}
        </dd>
      </dl>

      <p className="mt-4 text-xs text-slate-500">
        The guest is notified by email. Accepting also rejects the other pending requests that overlap this slot.
      </p>

      {errors.length > 0 && (
        <ul role="alert" className="mt-4 rounded bg-red-50 p-3 text-sm text-red-700">
          {errors.map((message) => (
            <li key={message}>{message}</li>
          ))}
        </ul>
      )}

      <div className="mt-6 flex gap-3">
        <button
          type="button"
          onClick={() => answer('rejected')}
          disabled={submitting !== null}
          className="flex-1 rounded border border-slate-300 px-4 py-2 text-sm text-slate-600 hover:bg-slate-50 disabled:opacity-60"
        >
          {submitting === 'rejected' ? 'Rejecting...' : 'Reject'}
        </button>
        <button
          type="button"
          onClick={() => answer('accepted')}
          disabled={submitting !== null}
          className="flex-1 rounded bg-brand-500 px-4 py-2 text-sm font-medium text-white hover:bg-brand-600 disabled:opacity-60"
        >
          {submitting === 'accepted' ? 'Accepting...' : 'Accept'}
        </button>
      </div>
    </Modal>
  )
}

export default AnswerRequestModal
