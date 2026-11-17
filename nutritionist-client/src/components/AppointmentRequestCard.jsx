import { formatDate, formatTime } from '../utils/dates'
import Avatar from './Avatar'
import StatusBadge from './StatusBadge'
import { CalendarIcon, ClockIcon } from './icons'

function AppointmentRequestCard({ appointmentRequest, onAnswer }) {
  const { guest, service, scheduled_at: scheduledAt } = appointmentRequest

  return (
    <article className="flex flex-col rounded border border-slate-200 bg-white shadow-sm">
      <div className="flex gap-4 p-5">
        <Avatar name={guest.name} className="h-14 w-14" />
        <div className="min-w-0 text-sm">
          <h2 className="truncate text-base text-slate-800">{guest.name}</h2>
          <p className="mb-2 truncate text-xs text-slate-500">{service.description}</p>
          <p className="flex items-center gap-2 text-slate-600">
            <CalendarIcon className="h-4 w-4 text-brand-500" />
            {formatDate(scheduledAt)}
          </p>
          <p className="flex items-center gap-2 text-slate-600">
            <ClockIcon className="h-4 w-4 text-brand-500" />
            {formatTime(scheduledAt)}
          </p>
        </div>
      </div>

      {appointmentRequest.status === 'pending' ? (
        <button
          type="button"
          onClick={() => onAnswer?.(appointmentRequest)}
          className="mt-auto border-t border-slate-200 py-3 text-sm font-medium text-brand-600 hover:bg-brand-50"
        >
          Answer request
        </button>
      ) : (
        <div className="mt-auto flex items-center justify-between border-t border-slate-200 px-5 py-3 text-xs text-slate-500">
          <StatusBadge status={appointmentRequest.status} />
          {appointmentRequest.answered_at && <span>Answered on {formatDate(appointmentRequest.answered_at)}</span>}
        </div>
      )}
    </article>
  )
}

export default AppointmentRequestCard
