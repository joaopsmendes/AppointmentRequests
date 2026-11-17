import { useState } from 'react'
import { createAppointmentRequest } from '../api/appointmentRequests'
import { errorMessages } from '../api/client'
import { toDateTimeLocalValue } from '../utils/dates'
import { formatPrice } from '../utils/formatPrice'
import ErrorList from './ErrorList'
import Modal from './Modal'

const inputClassName =
  'w-full rounded border border-slate-200 px-3 py-2 text-sm outline-none focus:border-brand-500 focus:ring-1 focus:ring-brand-500'

function ScheduleAppointmentModal({ nutritionist, initialService, onClose }) {
  const [serviceId, setServiceId] = useState(initialService.id)
  const [form, setForm] = useState({ name: '', email: '', scheduledAt: '' })
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [errors, setErrors] = useState([])
  const [isSuccess, setIsSuccess] = useState(false)
  const [minDateTime] = useState(() => toDateTimeLocalValue(new Date()))

  const service = nutritionist.services.find((candidate) => candidate.id === serviceId)

  function handleChange(event) {
    const { name, value } = event.target
    setForm((current) => ({ ...current, [name]: value }))
  }

  async function handleSubmit(event) {
    event.preventDefault()
    setIsSubmitting(true)
    setErrors([])

    try {
      await createAppointmentRequest({
        name: form.name,
        email: form.email,
        serviceId,
        scheduledAt: new Date(form.scheduledAt).toISOString(),
      })
      setIsSuccess(true)
    } catch (error) {
      setErrors(errorMessages(error))
    } finally {
      setIsSubmitting(false)
    }
  }

  if (isSuccess) {
    return (
      <Modal title="Request sent" onClose={onClose}>
        <p className="text-sm text-slate-600">
          Your request for <strong>{service.description}</strong> with <strong>{nutritionist.name}</strong> was
          sent. You will receive an email at <strong>{form.email}</strong> when it is answered.
        </p>
        <button
          type="button"
          onClick={onClose}
          className="mt-6 w-full rounded bg-brand-500 px-4 py-2 text-sm font-medium text-white hover:bg-brand-600"
        >
          Close
        </button>
      </Modal>
    )
  }

  return (
    <Modal title={`Schedule an appointment with ${nutritionist.name}`} onClose={onClose}>
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <label className="flex flex-col gap-1 text-sm">
          Service
          <select value={serviceId} onChange={(event) => setServiceId(Number(event.target.value))} className={inputClassName}>
            {nutritionist.services.map((option) => (
              <option key={option.id} value={option.id}>
                {option.description} · {formatPrice(option.price_cents)} · {option.duration_minutes} min
              </option>
            ))}
          </select>
        </label>

        <label className="flex flex-col gap-1 text-sm">
          Name
          <input name="name" value={form.name} onChange={handleChange} required autoFocus className={inputClassName} />
        </label>

        <label className="flex flex-col gap-1 text-sm">
          Email
          <input
            type="email"
            name="email"
            value={form.email}
            onChange={handleChange}
            required
            pattern="[^\s@]+@[^\s@]+\.[^\s@]+"
            title="Enter an email like name@example.com"
            className={inputClassName}
          />
        </label>

        <label className="flex flex-col gap-1 text-sm">
          Date and time
          <input
            type="datetime-local"
            name="scheduledAt"
            value={form.scheduledAt}
            onChange={handleChange}
            min={minDateTime}
            required
            className={inputClassName}
          />
        </label>

        <ErrorList messages={errors} />

        <button
          type="submit"
          disabled={isSubmitting}
          className="rounded bg-accent-500 px-4 py-2 text-sm font-medium text-white hover:bg-accent-600 disabled:opacity-60"
        >
          {isSubmitting ? 'Sending...' : 'Request appointment'}
        </button>
      </form>
    </Modal>
  )
}

export default ScheduleAppointmentModal
