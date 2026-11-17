import { useEffect, useState } from 'react'
import { listAppointmentRequests } from '../api/appointmentRequests'
import { formatDate, formatTime } from '../utils/dates'
import Modal from './Modal'
import StatusBadge from './StatusBadge'

const PER_PAGE = 5

function HistoryModal({ nutritionistId, onClose }) {
  const [page, setPage] = useState(1)
  const [result, setResult] = useState(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    let ignore = false

    async function loadHistory() {
      setIsLoading(true)
      setError(null)
      try {
        const response = await listAppointmentRequests(nutritionistId, { status: 'accepted,rejected', page, perPage: PER_PAGE })
        if (!ignore) setResult(response)
      } catch (requestError) {
        if (!ignore) setError(requestError)
      } finally {
        if (!ignore) setIsLoading(false)
      }
    }

    loadHistory()

    return () => {
      ignore = true
    }
  }, [nutritionistId, page])

  const totalPages = result?.meta.total_pages ?? 0

  return (
    <Modal title="History" onClose={onClose}>
      {error && <p className="rounded bg-red-50 p-3 text-sm text-red-700">Could not load the history. Please try again.</p>}

      {!error && !result && isLoading && <p className="text-sm text-slate-500">Loading history...</p>}

      {!error && result && (
        <div className={isLoading ? 'opacity-60' : undefined}>
          {result.data.length === 0 ? (
            <p className="text-sm text-slate-500">No answered requests yet.</p>
          ) : (
            <ul className="divide-y divide-slate-100 text-sm">
              {result.data.map((request) => (
                <li key={request.id} className="flex items-center justify-between gap-4 py-3">
                  <div className="min-w-0">
                    <p className="truncate text-slate-800">{request.guest.name}</p>
                    <p className="text-xs text-slate-500">
                      {formatDate(request.scheduled_at)}, {formatTime(request.scheduled_at)}
                    </p>
                  </div>
                  <div className="shrink-0 text-right">
                    <StatusBadge status={request.status} />
                    <p className="mt-1 text-xs text-slate-500">
                      Answered {formatDate(request.answered_at)} · {formatTime(request.answered_at)}
                    </p>
                  </div>
                </li>
              ))}
            </ul>
          )}

          {totalPages > 1 && (
            <div className="mt-4 flex items-center justify-between text-sm">
              <button
                type="button"
                onClick={() => setPage(page - 1)}
                disabled={page === 1}
                className="text-brand-600 disabled:cursor-not-allowed disabled:opacity-40"
              >
                ‹ Newer
              </button>
              <span className="text-slate-500">
                Page {page} of {totalPages}
              </span>
              <button
                type="button"
                onClick={() => setPage(page + 1)}
                disabled={page === totalPages}
                className="text-brand-600 disabled:cursor-not-allowed disabled:opacity-40"
              >
                Older ›
              </button>
            </div>
          )}
        </div>
      )}
    </Modal>
  )
}

export default HistoryModal
